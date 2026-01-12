#!/usr/bin/env python3
"""
pyfr_plot_from_config.py  ⟶  *v0.5*
====================================================
A *single‑file* utility that
1. **(re)builds a points CSV** from `lims` + `spacings` (unless `--reuse-points`).
2. **Runs `pyfr sampler sample`** automatically when the source is a `.pyfrs`.
3. **Evaluates user expressions** (e.g. `y/D`, `avg-u - Uin`) with constants from
   `[constants]` and geometry symbols (`STERN_X`, `D`, …).
4. **Plots** the line (and ±σ band) alongside any reference CSVs you list.

Changelog
---------
* **v0.5** – script finalised; plotting, refs, σ‑band, CLI `--reuse-points`.
* v0.4 – points regenerated every run.
* v0.3 – geometry variables.
* v0.2 – automatic sampler call.
* v0.1 – first release.
———————————————————————————————————————————————————————————————————————
"""
from __future__ import annotations

import argparse, ast, configparser, subprocess, sys
from pathlib import Path
import numpy as np
globals().setdefault('sqrt', np.sqrt)
import pandas as pd

from matplotlib import colors as mcolors

from util import infer_nx_ny_nz, spanwise_mean

from typing import Dict, Sequence

REF_FILL_CMAP = "viridis"   # global default

import matplotlib.pyplot as plt


plt.rcParams.update({
    "figure.dpi": 200,
    "savefig.dpi": 300,
    "axes.titlesize": 25,   # ↑
    "axes.labelsize": 25,   # ↑ xlabel/ylabel
    "xtick.labelsize": 20,  # ↑ xticks
    "ytick.labelsize": 20,  # ↑ yticks
    "legend.fontsize": 13,  # (optional) match scale
})


# ---------- pretty printer --------------------------------------------------
def _cyan(s):   return f"\033[96m{s}\033[0m"
def _green(s):  return f"\033[92m{s}\033[0m"
def _yellow(s): return f"\033[93m{s}\033[0m"
def _bold(s):   return f"\033[1m{s}\033[0m"

REF_STYLES = [dict(color="red"       , marker="o"),  
              dict(color="green"     , marker="s"),   
              dict(color="tab:blue"  , marker="^"),  
              dict(color="tab:orange", marker="D"),
              dict(color="purple"    , marker="v"),
]

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

import shlex
import glob as _glob

import matplotlib as mpl
from matplotlib.legend_handler import HandlerBase
from matplotlib.patches import Rectangle

class HandlerBandLine(HandlerBase):
    """Legend handler: draw a shaded band with a line on top (stacked)."""
    def create_artists(self, legend, orig_handle,
                       xdescent, ydescent, width, height, fontsize, trans):
        line_color, band_rgba = orig_handle  # tuple passed as the "handle"
        # band rectangle (60% of box height, vertically centered)
        band = Rectangle((xdescent, ydescent + 0.0*height),
                         width, 1*height,
                         transform=trans,
                         facecolor=band_rgba, edgecolor='none')
        # line across middle
        ymid = ydescent + 0.5*height
        line = mpl.lines.Line2D([xdescent, xdescent + width],
                                [ymid, ymid],
                                transform=trans,
                                color=line_color, linewidth=2.5)
        return [band, line]


_SUPS = "⁰¹²³⁴⁵⁶⁷⁸⁹"
def _sup(n: int) -> str:
    return "".join(_SUPS[ord(d) - 48] for d in str(n))

def _parse_reference_csv(path: Path, *, forced_label: str | None = None) -> pd.DataFrame:
    """Read a reference CSV and capture the first top comment (starting with '#')."""
    note = ""
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith("#"):
                note = s.lstrip("#").strip()
                break
            break  # header reached

    df = read_csv_any(path)
    # label priority: forced from spec > existing > filename stem
    df.attrs["label"] = forced_label or df.attrs.get("label") or path.stem
    if note:
        df.attrs["refnote"] = note

    return df

def load_reference_csvs_with_notes(spec: str) -> list[pd.DataFrame]:
    """
    Accepts ANY of:
      - whitespace and/or comma separated items
      - quoted paths with spaces
      - glob patterns (*.csv)
      - optional labels as  label=path  or  label:path  (DOIs are left intact)
    """
    if not spec or not spec.strip():
        return []

    # turn commas into whitespace and let shlex respect quotes
    tokens = shlex.split(spec.replace(",", " "))

    refs: list[pd.DataFrame] = []
    for tok in tokens:
        label = None
        path_txt = tok

        # Support label=path or label:path (but don't split DOIs or URLs)
        if ("=" in tok) or (":" in tok and not tok.startswith(("http://", "https://"))):
            # prefer '='; otherwise first ':' only
            if "=" in tok:
                label, path_txt = tok.split("=", 1)
            else:
                label, path_txt = tok.split(":", 1)
            label = label.strip()
            path_txt = path_txt.strip()

        # Expand globs; if none match, fall back to literal
        matches = sorted(_glob.glob(path_txt)) or [path_txt]
        for m in matches:
            p = Path(m)
            if not p.exists():
                print(f"[pyfr_plot] (warn) reference not found: {m}")
                continue

            # Skip if label like "_Hmode" or filename like "_Hmode.csv"
            if (label and label.startswith('_')) or p.stem.startswith('_'):
                print(f"[pyfr_plot] (note) skipping reference starting with '_': {p.name}")
                continue

            refs.append(_parse_reference_csv(p, forced_label=label))

    return refs


def _set_limits_with_padding(ax, xs, ys, pad_x=0.02, pad_y=0.06):
    """Autoscale to all data with a little padding so markers aren't cut."""
    import numpy as _np
    xs = _np.asarray(xs); ys = _np.asarray(ys)
    xmin, xmax = _np.nanmin(xs), _np.nanmax(xs)
    ymin, ymax = _np.nanmin(ys), _np.nanmax(ys)
    xr = xmax - xmin or 1.0
    yr = ymax - ymin or 1.0
    ax.set_xlim(xmin - pad_x * xr, xmax + pad_x * xr)
    ax.set_ylim(ymin - pad_y * yr, ymax + pad_y * yr)


def first_key(sect: configparser.SectionProxy, *names: str, default: str | None = None):
    """Return the first existing key among *names* (case‑insensitive)."""
    for k in names:
        if k in sect:
            return sect[k]
    if default is not None:
        return default
    raise KeyError(f"None of the keys {', '.join(names)} found in section [{sect.name}]")


def get_label(cfg, sect, base, key: str, fallback: str = "") -> str:
    # 1) section
    if key in sect:
        return sect[key]
    # 2) family base (may be dict or SectionProxy)
    if base and key in base:
        return base[key]
    # 3) global defaults
    if "plot-defaults" in cfg and key in cfg["plot-defaults"]:
        return cfg["plot-defaults"][key]
    # 4) fallback
    return fallback


def read_csv_any(path: Path) -> pd.DataFrame:
    """Read CSV with either comma or whitespace separators."""
    try:
        return pd.read_csv(path, comment="#", skip_blank_lines=True)
    except (pd.errors.ParserError, UnicodeDecodeError):
        return pd.read_csv(path, delim_whitespace=True, comment="#", skip_blank_lines=True)

def eval_expr(expr: str, env: Dict[str, np.ndarray | float]):
    """Evaluate *expr* in a restricted, NumPy‑friendly namespace."""
    allowed = {**env, "np": np, "sqrt": np.sqrt, "sin": np.sin, "cos": np.cos,
        "tan": np.tan, "log": np.log, "exp": np.exp, "pi": np.pi, }
    return eval(expr, {"__builtins__": {}}, allowed)

# ----------------------------------------------------------------------------
# Geometry helper – injects START_X, STREAM_LEN, D, STERN_X, …
# ----------------------------------------------------------------------------

def geometry_env(cfg: configparser.ConfigParser) -> Dict[str, float]:
    env: Dict[str, float] = {}
    if "postprocess-geometry" in cfg:
        g = cfg["postprocess-geometry"]

        def parse_tuple(txt: str):
            txt = txt.strip().lstrip("([{}").rstrip(")] {}")
            return tuple(map(float, txt.split(',')))

        sx, sy, sz = parse_tuple(g.get("start", "0,0,0"))
        env.update({"START_X": sx, "START_Y": sy, "START_Z": sz})

        stream_len = float(g.get("streamwiselength", g.get("length-streamwise", 0)))
        span_len = float(g.get("spanwiselength", g.get("length-spanwise", 0)))
        env.update({"STREAM_LEN": stream_len, "SPAN_LEN": span_len, "D": span_len})
        env["STERN_X"] = sx + stream_len


        env["streamwiselength"] = stream_len
        env["spanwiselength"]   = span_len
    return env

# ----------------------------------------------------------------------------
# Points CSV generator
# ----------------------------------------------------------------------------

def infer_nx_ny_nz(arr_len: int, spacings: str) -> tuple[int,int]:
    """
    Work out ny,nz from array length and the user’s [nx,ny,nz] list,
    allowing nx or nz to be 1 (line-like extraction).
    """
    nx, ny, nz = (int(ast.literal_eval(s.strip()))
                  for s in spacings.strip("[]").split(','))

    if arr_len == nx * ny * nz:
        return nx, ny, nz


    raise ValueError("Cannot deduce ny,nz – check spacings vs sampled size.")



def make_points_csv(pts_path: Path, lims: str, spacings: str, env: Dict[str, float]):
    """Generate Cartesian grid points and save to *pts_path*."""

    def _vec(txt: str):
        txt = txt.strip().lstrip("[(").rstrip(")] ")
        comps = [c.strip() for c in txt.split(',')]
        return tuple(float(eval(c, {"__builtins__": {}}, env)) for c in comps)

    p0_txt, p1_txt = lims.strip("[]").split("),")
    p0, p1 = _vec(p0_txt + ")"), _vec(p1_txt)

    nx, ny, nz = (int(ast.literal_eval(s.strip())) for s in spacings.strip("[]").split(','))

    def lin(a, b, n):
        return np.linspace(a, b, n) if n > 1 else np.array([a])

    xs, ys, zs = lin(p0[0], p1[0], nx), lin(p0[1], p1[1], ny), lin(p0[2], p1[2], nz)
    pts = np.array([[x, y, z] for x in xs for y in ys for z in zs])
    pts_path.parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(pts_path, pts, delimiter=',', header='x,y,z', comments='')

# ----------------------------------------------------------------------------
# Plot utility
# ----------------------------------------------------------------------------

from matplotlib import colors as mcolors

def plot_line(x, y, std, refs, outfile, xlabel, ylabel, title="",
              show_legend=True, show_ref_notes=True, *, pyfr_label="PyFR"):
    plt.figure(figsize=(10, 5.2))
    ax = plt.gca()

    # --- PyFR band then line (line above the band) ---
    py_line_obj = None
    std_obj = None
    base_col = "tab:blue"
    band_rgba = mcolors.to_rgba(base_col, alpha=0.22)
    std_obj = None
    if std is not None:
        std_obj = plt.fill_between(x, y - std, y + std,
                                facecolor=band_rgba, linewidth=0, zorder=1)
    py_line_obj = plt.plot(x, y, color=base_col, lw=3, zorder=2,
                        solid_capstyle="round")[0]

    # --- collect limits (so markers aren’t clipped) ---
    all_x, all_y = [x], [y]
    if std is not None:
        all_y += [y - std, y + std]

    ref_handles, ref_labels, notes = [], [], []
    for i, ref in enumerate(refs):
        rx, ry = ref.iloc[:, 0].values, ref.iloc[:, 1].values
        all_x.append(rx); all_y.append(ry)
        base_lbl = ref.attrs.get("label", ref.iloc[:, 0].name or "ref")
        note = ref.attrs.get("refnote", "")
        sup = ""
        if note:
            notes.append(note); sup = _sup(len(notes))
        style = REF_STYLES[i % len(REF_STYLES)]
        h = plt.scatter(rx, ry, s=5, facecolors="none",
                        edgecolors=style["color"], marker=style["marker"],
                        linewidths=1.0, clip_on=False, zorder=3)
        ref_handles.append(h); ref_labels.append(f"{base_lbl}{sup}")

    import numpy as _np
    _set_limits_with_padding(ax, _np.concatenate(all_x), _np.concatenate(all_y),
                             pad_x=0.02, pad_y=0.08)

    plt.xlabel(xlabel); plt.ylabel(ylabel)
    if title: plt.title(title)

    # --- footnotes (unchanged) ---
    if show_ref_notes and notes:
        y0, dy = 0.012, 0.018
        bottom = y0 + dy*len(notes) + 0.018
        plt.tight_layout(rect=[0.0, bottom, 1.0, 1.0])
        fig = plt.gcf()
        for i, txt in enumerate(notes):
            fig.text(0.5, y0 + dy*i, f"{_sup(i+1)} {txt}",
                     ha="center", va="bottom", fontsize=8)
    else:
        plt.tight_layout(rect=[0.0, 0.04, 1.0, 1.0])

    # --- legend: single entry for (band + line) so they appear stacked ---
    if show_legend:
        handles, labels = [], []
        if std is not None:
            pyfr_handle = (py_line_obj.get_color(), band_rgba)
            handles.append(pyfr_handle)
            labels.append(f"{pyfr_label} (μ±σ)")
        else:
            handles.append(py_line_obj)
            labels.append(pyfr_label)

        # append ref handles/labels you already collected as (scatter, label)
        handles += ref_handles
        labels  += ref_labels

        ncols = 2 if len(refs) >= 3 else 1
        plt.legend(handles, labels, frameon=False, ncol=ncols,
                handler_map={tuple: HandlerBandLine()})

    outfile.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(outfile, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"[pyfr_plot] Saved → {outfile}")



def plot_plane(x2d, y2d, z2d, 
               outfile, 
               xlabel, ylabel, zlabel, title=""):
    plt.figure(figsize=(10, 8))
    # —— Posa-style rainbow palette & fixed 0–1 range ——
    levels = np.linspace(0.0, 1.0, 21)           # 0-1 by 0.05
    cf = plt.contourf(x2d, y2d, z2d,
                      levels=levels,
                      cmap="turbo",              # vivid rainbow (Matplotlib ≥3.4)
                      extend="both")

    cb = plt.colorbar(cf,
                      orientation="horizontal",
                      pad=0.08,
                      aspect=40)
    cb.set_ticks(np.linspace(0, 1, 6))           # 0,0.2,…,1
    cb.set_label(zlabel)

    cb.set_label(zlabel)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    if title:
        plt.title(title)
    
    plt.gca().set_aspect("equal")
    plt.tight_layout()
    outfile.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(outfile, dpi=300)
    plt.close()
    print(f"[pyfr_plot] Saved → {outfile}")

def _clean_ascii(expr: str) -> str:
    # normal minus signs
    for bad in ('\u2010', '\u2011', '\u2012', '\u2013', '\u2212'):
        expr = expr.replace(bad, '-')
    # remove strange line separators / zero-width spaces
    expr = expr.replace('\u2028', '').replace('\u2029', '').replace('\u200b', '')
    return expr.strip()

# ----------------------------------------------------------------------------
# Main driver
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Main driver – now only a tiny wrapper
# ----------------------------------------------------------------------------
def main(argv: Sequence[str] | None = None):
    ap = argparse.ArgumentParser(
        description="Sample a PyFR solution, build points on the fly, and plot.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    ap.add_argument("ini",     help="PyFR run .ini file")
    ap.add_argument("section", help="Post-processing section to use")
    ap.add_argument("--xexpr")
    ap.add_argument("--yexpr")
    ap.add_argument("--stdexpr")
    ap.add_argument("--skip", type=int, help="--skip value for pyfr sampler")

    ap.add_argument("--no-legend", action="store_true",
                    help="Hide the legend for this plot")
    ap.add_argument("--no-ref-notes", action="store_true",
                    help="Do not print reference footnotes (still plots ref markers)")


    # NEW: reuse flag for an existing sampled CSV
    ap.add_argument("--reuse",
                    metavar="CSV",
                    nargs="?",
                    const="",
                    help="If CSV exists, re-use it instead of re-sampling")
    args = ap.parse_args(argv)

    # --- read the .ini -------------------------------------------------
    cfg = configparser.ConfigParser()
    cfg.optionxform = str          # preserve case (Uin, Pr, …)
    cfg.read(args.ini)

    # --- now run the requested section ---------------------------------
    _run_section(cfg, args.section, args, subcall=False)

def build_title(cfg, sect, base, sec_name, mean_flag, *, is_plane):
    t = get_label(cfg, sect, base, "title", fallback="")
    if not t:
        root = sec_name.split(f"postprocess-{'sampleplane' if is_plane else 'sampleline'}-", 1)[-1]
        root = root.replace('-', ' ').replace('_', '-').title()
        t = root
    return t





import os

def _as_bool(v) -> bool:
    if v is None:
        return False
    if isinstance(v, bool):
        return v
    return str(v).strip().lower() in {"1", "true", "yes", "y", "on"}

def _split_tokens(s: str) -> list[str]:
    return shlex.split(s.replace(",", " ")) if s else []

def _get_any(sect, base, *keys, default=None):
    for k in keys:
        if k in sect:
            return sect.get(k)
        if isinstance(base, dict):
            if k in base:
                return base.get(k)
        else:
            if k in base:
                return base.get(k)
    return default

def _detect_point_cols(cols):
    cands = [("Points:0", "Points:1", "Points:2"),
             ("Points_0", "Points_1", "Points_2")]
    for a, b, c in cands:
        if a in cols and b in cols and c in cols:
            return a, b, c
    raise KeyError("Could not find coordinate columns (expected Points:0/1/2).")

def _align_to_chord_xy(xy, *, x_end_frac=1e-3):
    """
    Robust chord frame:
      - LE = mean of points with x within x_end_frac * chord of xmin
      - TE = mean of points with x within x_end_frac * chord of xmax
    This avoids picking a single upper-surface point as LE/TE.
    """
    xy = np.asarray(xy, dtype=float)

    xmin = float(xy[:, 0].min())
    xmax = float(xy[:, 0].max())
    xr = xmax - xmin
    if xr <= 0.0:
        raise RuntimeError("Degenerate x-range; cannot define chord.")

    tol = x_end_frac * xr

    le_pts = xy[np.abs(xy[:, 0] - xmin) <= tol]
    te_pts = xy[np.abs(xy[:, 0] - xmax) <= tol]

    # Fallbacks if tolerance too tight
    le = le_pts.mean(axis=0) if len(le_pts) else xy[np.argmin(xy[:, 0])]
    te = te_pts.mean(axis=0) if len(te_pts) else xy[np.argmax(xy[:, 0])]

    chord = te - le
    c = float(np.linalg.norm(chord))
    if c == 0.0:
        raise RuntimeError("Chord length is zero (degenerate geometry).")

    t = chord / c
    n = np.array([-t[1], t[0]])

    rel = xy - le
    xprime = rel @ t
    yprime = rel @ n

    return le, te, c, xprime / c, yprime

def _surface_envelope(x_over_c, y_signed, mu, sig=None, *, nbins=600, eps=0.0):
    """
    Build upper/lower envelopes by x/c bins.

    Critical fix:
      - upper candidates: y_signed > +eps
      - lower candidates: y_signed < -eps
    If a bin has no candidates for a side, we skip that bin for that side.
    Also: write x as BIN CENTER (prevents repeated-x vertical segments).
    """
    x = np.clip(np.asarray(x_over_c, dtype=float), 0.0, 1.0)
    y = np.asarray(y_signed, dtype=float)
    mu = np.asarray(mu, dtype=float)
    sig = np.asarray(sig, dtype=float) if sig is not None else None

    bins = np.linspace(0.0, 1.0, nbins + 1)
    ib = np.digitize(x, bins) - 1
    valid = (ib >= 0) & (ib < nbins)

    x, y, mu, ib = x[valid], y[valid], mu[valid], ib[valid]
    if sig is not None:
        sig = sig[valid]

    xu, muu, sigu = [], [], []
    xl, mul, sigl = [], [], []

    for b in range(nbins):
        xc = 0.5 * (bins[b] + bins[b + 1])  # BIN CENTER

        m = (ib == b)
        if not np.any(m):
            continue

        idx = np.where(m)[0]

        # --- upper: only y > +eps
        iu_cand = idx[y[idx] > +eps]
        if iu_cand.size:
            iu = iu_cand[np.argmax(y[iu_cand])]
            xu.append(xc); muu.append(mu[iu])
            if sig is not None: sigu.append(sig[iu])

        # --- lower: only y < -eps
        il_cand = idx[y[idx] < -eps]
        if il_cand.size:
            il = il_cand[np.argmin(y[il_cand])]
            xl.append(xc); mul.append(mu[il])
            if sig is not None: sigl.append(sig[il])

    out = {
        "upper": (np.asarray(xu), np.asarray(muu)),
        "lower": (np.asarray(xl), np.asarray(mul)),
    }
    if sig is not None:
        out["upper_sig"] = np.asarray(sigu) if len(sigu) else None
        out["lower_sig"] = np.asarray(sigl) if len(sigl) else None

    print(f"[paraview-envelope] nbins={nbins} upper_pts={len(xu)} lower_pts={len(xl)}")
    return out


def plot_upper_lower(xu, yu, su, xl, yl, sl, refs, outfile, xlabel, ylabel, *,
                     title="", shade_std=False):
    plt.figure(figsize=(10, 5.2))
    ax = plt.gca()

    # upper/lower lines
    lu = plt.plot(xu, yu, lw=3, label="upper")[0]
    ll = plt.plot(xl, yl, lw=3, label="lower")[0]

    # optional ±σ shading
    if shade_std and su is not None:
        plt.fill_between(xu, yu - su, yu + su, color=lu.get_color(), alpha=0.18, linewidth=0)
    if shade_std and sl is not None:
        plt.fill_between(xl, yl - sl, yl + sl, color=ll.get_color(), alpha=0.18, linewidth=0)

    # references (keep your “filled small markers” style)
    for i, ref in enumerate(refs):
        rx, ry = ref.iloc[:, 0].values, ref.iloc[:, 1].values
        style = REF_STYLES[i % len(REF_STYLES)]
        plt.scatter(rx, ry, s=8, marker=style["marker"], label=ref.attrs.get("label", ref.columns[1]),
                    linewidths=1.0)

    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    if title:
        plt.title(title)

    plt.grid(True, which="both")
    plt.legend(frameon=False, ncol=2 if len(refs) >= 3 else 1)
    plt.tight_layout()

    outfile.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(outfile, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"[pyfr_plot] Saved → {outfile}")

def _run_paraview_family(cfg, sec_name, sect, base, env0, args, *, subcall: bool):
    # --- config
    pvpython = Path(_get_any(sect, base, "pvpython", default="pvpython"))
    pvtocsv  = Path(_get_any(sect, base, "pvtocsv", default="pvtocsv.py"))
    input_vtu = Path(_get_any(sect, base, "input-vtu", "input_vtu", "src-file", "src", default=""))
    if not str(input_vtu):
        sys.exit("[pyfr_plot] paraview family requires input-vtu (or src-file).")

    arrays = _split_tokens(_get_any(sect, base, "arrays", default=""))
    mu_col = _get_any(sect, base, "mu-col", "mu_col", default=(arrays[0] if arrays else "Avg-P"))
    sig_col = _get_any(sect, base, "sig-col", "sig_col", default=(arrays[1] if len(arrays) > 1 else ""))

    weighting = _get_any(sect, base, "weighting", default="average_by_number")
    point_merge = _as_bool(_get_any(sect, base, "point-merge", "point_merge", default=False))

    nbins = int(_get_any(sect, base, "nbins", default=600))
    shade_std = _as_bool(_get_any(sect, base, "shade-std", "shade_std", default=False))

    ctg_csv = Path(_get_any(sect, base, "ctg-csv", "ctg_csv",
                            default=f"{input_vtu.stem}-ctg.csv"))

    out_csv = Path(_get_any(sect, base, "sampled-file", "out-csv", "out_csv",
                            default=f"{sec_name}.csv"))
    out_fig = Path(_get_any(sect, base, "file", "output",
                            default=f"{sec_name}.png"))

    xexpr = _clean_ascii(_get_any(sect, base, "xexpr", default="x_over_c"))
    yexpr = _clean_ascii(_get_any(sect, base, "yexpr", default="mu"))
    stdexpr = _clean_ascii(_get_any(sect, base, "stdexpr", default="")) or None

    refs = load_reference_csvs_with_notes(_get_any(sect, base, "reference", default=""))

    # --- run ParaView only if needed
    if not ctg_csv.exists():
        cmd = [str(pvpython), "--mesa", str(pvtocsv),
               "-i", str(input_vtu),
               "-o", str(ctg_csv),
               "--weighting", str(weighting)]
        if point_merge:
            cmd.append("--point-merge")
        if arrays:
            cmd += ["--arrays", *arrays]

        print("[pyfr_plot] (paraview) run:", " ".join(cmd))
        subprocess.run(cmd, check=True)

    # --- load CTG CSV
    df = pd.read_csv(ctg_csv)
    px, py, pz = _detect_point_cols(df.columns)

    if mu_col not in df.columns:
        sys.exit(f"[pyfr_plot] mu-col '{mu_col}' not in {ctg_csv}")
    if sig_col and sig_col not in df.columns:
        print(f"[pyfr_plot] (warn) sig-col '{sig_col}' not found; std disabled.")
        sig_col = ""

    xy = df[[px, py]].to_numpy()

    le, te, c, x_over_c, y_signed = _align_to_chord_xy(xy)


    print(f"[pyfr_plot] (paraview) chord: c={c:.10f} LE=({le[0]:.7f},{le[1]:.7f}) TE=({te[0]:.7f},{te[1]:.7f})")

    mu = df[mu_col].to_numpy()
    sig = df[sig_col].to_numpy() if sig_col else None

    env_common = dict(env0)
    # Evaluate expressions separately on envelope points
    env_upper = dict(env_common)
    env_lower = dict(env_common)

    env = _surface_envelope(x_over_c, y_signed, mu, sig, nbins=nbins)

    # pick which side this section is responsible for
    side = str(_get_any(sect, base, "side", default="upper")).strip().lower()
    if side not in {"upper", "lower"}:
        sys.exit("[pyfr_plot] paraview: side must be 'upper' or 'lower'")

    if side == "upper":
        xs, mus = env["upper"]
        sigs = env.get("upper_sig", None)
    else:
        xs, mus = env["lower"]
        sigs = env.get("lower_sig", None)

    # build evaluation env for this side only
    env_side = dict(env0)
    env_side.update({
        "x_over_c": xs,
        "mu": mus,
        "sig": (sigs if sigs is not None else np.zeros_like(mus)),
        "avg_p": mus,
        "std_p": (sigs if sigs is not None else np.zeros_like(mus)),
    })

    x1 = np.asarray(eval_expr(xexpr, env_side), dtype=float)
    y1 = np.asarray(eval_expr(yexpr, env_side), dtype=float)
    s1 = (np.asarray(eval_expr(stdexpr, env_side), dtype=float)
          if (stdexpr and sigs is not None) else None)

    # write a simple LaTeX-friendly CSV: x,y[,std]
    out = pd.DataFrame({"x": x1, "y": y1})
    if s1 is not None:
        out["std"] = s1
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(out_csv, index=False)
    print(f"[pyfr_plot] (paraview) wrote → {out_csv}")

    xlabel = get_label(cfg, sect, base, "xlabel", fallback=r"$x/c$")
    ylabel = get_label(cfg, sect, base, "ylabel", fallback=yexpr)
    title  = get_label(cfg, sect, base, "title", fallback=sec_name)

    # plot as a normal 1-line plot (same style as sampleline)
    plot_line(
        x1, y1, s1, refs, out_fig,
        xlabel=xlabel, ylabel=ylabel, title=title,
        show_legend=True, show_ref_notes=True,
        pyfr_label=side,
    )




def _sort_dedupe_1d(x, y, s=None):
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    if s is not None:
        s = np.asarray(s, dtype=float)

    # sort by x
    idx = np.argsort(x, kind="mergesort")
    x, y = x[idx], y[idx]
    if s is not None:
        s = s[idx]

    # de-duplicate x (keep first or average; average is safer)
    ux, inv, counts = np.unique(x, return_inverse=True, return_counts=True)
    if len(ux) != len(x):
        y_acc = np.zeros_like(ux, dtype=float)
        if s is not None:
            s_acc = np.zeros_like(ux, dtype=float)

        np.add.at(y_acc, inv, y)
        if s is not None:
            np.add.at(s_acc, inv, s)

        y = y_acc / counts
        if s is not None:
            s = s_acc / counts
        x = ux

    return x, y, s


def _pass_slurm_pmi_fd_to_child() -> tuple[int, ...]:
    """
    Under Slurm+PMI2, MPICH uses PMI_FD to talk to the PMI server.
    That FD is close-on-exec by default, so subprocesses lose it unless
    we explicitly pass it through exec() via pass_fds.
    """
    pmi = os.environ.get("PMI_FD", "")
    if not pmi:
        return ()

    try:
        fd = int(pmi)
    except ValueError:
        print("[pyfr_plot] (mpi) PMI_FD is not an int; not passing to child", flush=True)
        return ()

    try:
        os.set_inheritable(fd, True)
    except OSError as e:
        print(f"[pyfr_plot] (mpi) could not set PMI_FD inheritable: {e}", flush=True)
        return ()

    print("[pyfr_plot] (mpi) passing PMI_FD to child so MPICH can initialise", flush=True)
    return (fd,)








# ----------------------------------------------------------------------------
# Helper: run one post-processing section (line OR plane)
# ----------------------------------------------------------------------------
def _run_section(cfg: configparser.ConfigParser,
                 sec_name: str,
                 args: argparse.Namespace,
                 *,
                 subcall: bool):
    """
    Everything that used to live in main() now happens here, so we can call
    it twice: once for the base sampling-plane, once for the user-requested
    section.  When *subcall* is True we stay quiet after finishing.
    """

    if sec_name not in cfg:
        sys.exit(f"[pyfr_plot] Section '{sec_name}' not found in INI")

    sect = cfg[sec_name]

    # ------------------------------------------------------------------
    # 0. Constants, geometry helpers, env0   (UNCHANGED CODE)
    # ------------------------------------------------------------------
    const_env: Dict[str, float] = {}
    if "constants" in cfg:
        for k, v in cfg["constants"].items():
            v_clean = v.split(';', 1)[0].split('#', 1)[0].strip()
            if not v_clean:
                continue
            val = float(eval(v_clean, {"__builtins__": {}}, const_env))
            const_env[k] = val
            const_env[k.replace('-', '_')] = val
    env0 = {**const_env, **geometry_env(cfg)}

    # ------------------------------------------------------------------
    # 1. Work out where to find / place:   pts-file   &   sampled-file
    # ------------------------------------------------------------------
    
    # ─── at the top of _run_section (replace current base = … line) ───
    family = sec_name.split('-', 2)[1]              # "sampleline", "sampleplane", …
    base_key = f"postprocess-{family}-base"
    base = cfg[base_key] if base_key in cfg else {}
    

    if family == "paraview":
        return _run_paraview_family(cfg, sec_name, sect, base, env0, args, subcall=subcall)




    pts_path = Path(sect.get("pts-file", base.get("pts-file", f"{sect.get('src-file','sample')}_pts.csv")))

    if args.reuse is not None:
        csv_out = Path(args.reuse or
                       sect.get("sampled-file", base.get("sampled-file", "")) or
                       f"{pts_path.stem.replace('_pts','')}_sampled.csv")
    else:
        csv_out = Path(sect.get("sampled-file", base.get("sampled-file", "")) or
                       f"{pts_path.stem.replace('_pts','')}_sampled.csv")

    # ------------------------------------------------------------------
    # 2. Build points file once
    # ------------------------------------------------------------------
    if not pts_path.exists():
        # grab whatever each block provides
        lims     = sect.get("lims",     base.get("lims",     ""))
        spacings = sect.get("spacings", base.get("spacings", ""))

        # build only if we actually have both keys
        if lims and spacings:
            print(f"[pyfr_plot] Building points file {pts_path.name} …")
            make_points_csv(pts_path, lims, spacings, env0)
        else:
            if subcall:
                # base pass: silently skip — derived sections will supply lims
                return
            sys.exit("[pyfr_plot] Need 'lims' + 'spacings' (from this "
                     "section *or* the base) to create the points file.")

    def _get_src_path(sect, base):
        for key in ("src-file", "src"):
            if key in sect:
                return Path(sect[key])
            if key in base:
                return Path(base[key])
        raise SystemExit("[pyfr_plot] No src-file (PyFR solution) given")

    # …
    src_path = _get_src_path(sect, base)


    # ------------------------------------------------------------------
    # 1½.  Colourful summary – printed first
    # ------------------------------------------------------------------
    if not subcall:           # hide it during the silent base pass
        banner = [
            _bold(f"\n╭─ {sec_name}"),
                    f"│  src-path : {_cyan(src_path)}",
                    f"│  pts-path : {_cyan(pts_path)}",
        
                    f"│  lims     : {_green(sect.get('lims', base.get('lims', '')))}",
                    f"│  spacings : {_green(sect.get('spacings', base.get('spacings','')))}",
        
                    f"│  xexpr    : {_yellow(sect.get('xexpr', ''))}",
                    f"│  yexpr    : {_yellow(sect.get('yexpr', ''))}",
                    f"│  zexpr    : {_yellow(sect.get('zexpr', '—'))}",
                    f"╰─────────────────────────────────────────────────────"
        ]
        print("\n".join(banner))

    # ------------------------------------------------------------------
    # 3. Sample .pyfrs only if sampled CSV missing
    # ------------------------------------------------------------------


    mesh_path = Path(first_key(sect, "mesh",
                               default=cfg.get("postprocess-mesh", "mesh-native", fallback="")))
    if not csv_out.exists():
        skip_val = args.skip if args.skip is not None else int(sect.get("skip", 1))
        sampler_cmd = [
            "pyfr", "sampler", "sample",
            f"--skip={skip_val}",
            f"--pts={pts_path}",
            "-s,", str(mesh_path), str(src_path)
        ]
        print("[pyfr_plot] Running:", " ".join(sampler_cmd), flush=True)

        pass_fds = _pass_slurm_pmi_fd_to_child()

        with csv_out.open("w") as fh:
            subprocess.run(sampler_cmd, check=True, stdout=fh, pass_fds=pass_fds)
    else:
        print(f"[pyfr_plot] Re-using sampled CSV → {csv_out}")

    # ------------------------------------------------------------------
    # 4. Replace src_path by the sampled CSV & proceed with the *old*
    #    expression-evaluation and plotting code (unchanged).
    # ------------------------------------------------------------------
    src_path = csv_out

    # ------------------------------------------------------------------
    # 5.  Load CSV, evaluate expressions, make the plot  (restored)
    # ------------------------------------------------------------------
    df = read_csv_any(src_path)
    env = {**{c.replace('-', '_'): df[c].values for c in df.columns}, **env0}
    env["u_min"] = float(env["avg_u"].min())

    # helper so we stop repeating ourselves
    inherit = lambda key, default="": sect.get(key, base.get(key, default))

    lims      = inherit("lims")
    spacings  = inherit("spacings")
    xexpr     = _clean_ascii(inherit("xexpr"))
    yexpr     = _clean_ascii(inherit("yexpr"))
    zexpr     = _clean_ascii(inherit("zexpr"))
    stdexpr   = _clean_ascii(inherit("stdexpr")) or None

    # --- optional span-wise averaging -----------------------------------
    want_zmean = bool(sect.get("zmean", base.get("zmean", "")))


    # nothing to plot → stop early
    if not (xexpr and yexpr) and not zexpr:
        print("[pyfr_plot] Section has no expressions – nothing to plot.")
        return

    try:
        x   = np.asarray(eval_expr(xexpr, env), dtype=float) if xexpr else None
        y   = np.asarray(eval_expr(yexpr, env), dtype=float) if yexpr else None
        z   = np.asarray(eval_expr(zexpr, env), dtype=float) if zexpr else None
        std = np.asarray(eval_expr(stdexpr, env), dtype=float) if stdexpr else None
    except Exception as e:
        sys.exit(f"[pyfr_plot] Expression error → {e}")

    outfile = Path(first_key(sect, "file", "output",
                             default=f"{sec_name}.png"))
    outfile.parent.mkdir(parents=True, exist_ok=True)

    # ――― figure title: explicit key > suffix of section name ―――

    # ───────────────────── 2-D plane or 1-D line  ──────────────────────


    xlb = get_label(cfg, sect, base, "xlabel", fallback=(xexpr or ""))
    ylb = get_label(cfg, sect, base, "ylabel", fallback=(yexpr or ""))
    zlb = get_label(cfg, sect, base, "zlabel", fallback=(zexpr or ""))


    if zexpr:                                         # 2-D contour
        nx, ny, nz = infer_nx_ny_nz(len(x), spacings)
        x2d, y2d, z2d = (a.reshape(ny, nz) for a in (x, y, z))

        if want_zmean:                               # collapse z once, reuse
            y2d = y2d.mean(1, keepdims=True)
            z2d = z2d.mean(1, keepdims=True)
            x2d = x2d[:, :1]

        title = build_title(cfg, sect, base, sec_name, want_zmean, is_plane=True)
        plot_plane(x2d, y2d, z2d, outfile, xlabel=xlb, ylabel=ylb, zlabel=zlb, title=title)

    else:                                             # 1-D profile
        if want_zmean:
            nx, ny, nz = infer_nx_ny_nz(len(x), spacings)
            x = spanwise_mean(x, nx, ny, nz)
            y = spanwise_mean(y, nx, ny, nz)
            if std is not None:
                std = std.reshape(nx if ny == 1 else ny, nz)
                std = np.sqrt((std**2).sum(1)) / nz   # √Σσ² / nz

        refs = load_reference_csvs_with_notes(sect.get('reference', ''))

        title = build_title(cfg, sect, base, sec_name, want_zmean, is_plane=False)


        # ------------------------------------------------------------------
        # Write LaTeX-ready CSV at the *exact plotting location*
        # (same data as the PNG, no reordering later)
        # ------------------------------------------------------------------

        csv_out = Path(
            sect.get("csv-file",
                    base.get("csv-file",
                            outfile.with_suffix(".csv")))
        )

        # Safety: ensure x is unique & sorted exactly as plotted
        x1, y1, s1 = _sort_dedupe_1d(x, y, std)

        df_csv = pd.DataFrame({
            "x": x1,
            "y": y1,
            **({"std": s1} if s1 is not None else {})
        })

        csv_out.parent.mkdir(parents=True, exist_ok=True)
        df_csv.to_csv(csv_out, index=False)

        print(f"[pyfr_plot] Wrote plot-aligned CSV → {csv_out}")


        plot_line(
            x, y, std, refs, outfile,
            xlabel=xlb, ylabel=ylb, title=title,
            show_legend=not args.no_legend,
            show_ref_notes=not args.no_ref_notes,
        )

    # At the end:
    if subcall:
        return  # silent exit when this is the preliminary base run

if __name__ == "__main__":
    main()
