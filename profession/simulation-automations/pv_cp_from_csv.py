#!/usr/bin/env python3
from __future__ import annotations

import argparse
import configparser
import shlex
import subprocess
from pathlib import Path
import glob
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


# -------------------------- small utilities --------------------------
def _detect_point_cols(cols):
    cands = [("Points:0", "Points:1", "Points:2"),
             ("Points_0", "Points_1", "Points_2"),
             ("x", "y", "z")]
    for a, b, c in cands:
        if a in cols and b in cols and c in cols:
            return a, b, c
    raise KeyError(f"Could not find coordinate columns. Have: {list(cols)}")


def read_csv_any(path: Path) -> pd.DataFrame:
    # Handles normal CSV + “x,Cp” with spaces after comma
    return pd.read_csv(path, comment="#", skip_blank_lines=True, skipinitialspace=True)


def load_reference_csvs(spec: str) -> list[tuple[str, np.ndarray, np.ndarray]]:
    """
    spec supports:
      - comma/space separated items
      - glob patterns
      - optional label=path or label:path
    """
    if not spec or not spec.strip():
        return []

    toks = shlex.split(spec.replace(",", " "))
    out = []
    for tok in toks:
        label = None
        pat = tok

        if "=" in tok:
            label, pat = tok.split("=", 1)
        elif ":" in tok and not tok.startswith(("http://", "https://")):
            label, pat = tok.split(":", 1)

        matches = sorted(glob.glob(pat)) or [pat]
        for m in matches:
            p = Path(m)
            if not p.exists():
                print(f"[ref] (warn) missing: {m}")
                continue

            df = read_csv_any(p)
            if df.shape[1] < 2:
                print(f"[ref] (warn) needs 2 cols: {p}")
                continue

            x = df.iloc[:, 0].to_numpy(dtype=float)
            y = df.iloc[:, 1].to_numpy(dtype=float)
            o = np.argsort(x)

            lbl = (label.strip() if label else p.stem)
            out.append((lbl, x[o], y[o]))

    print(f"[ref] n={len(out)}")
    return out


def eval_constants(cfg: configparser.ConfigParser) -> dict[str, float]:
    env: dict[str, float] = {}
    if "constants" in cfg:
        for k, v in cfg["constants"].items():
            v_clean = v.split(";", 1)[0].split("#", 1)[0].strip()
            if not v_clean:
                continue
            env[k] = float(eval(v_clean, {"__builtins__": {}}, env))
            env[k.replace("-", "_")] = env[k]
    return env


# -------------------------- pvpython call --------------------------
def run_clean_to_grid(*, pvpython: str, ctg_script: str,
                      input_vtu: Path, output_csv: Path,
                      arrays: list[str], weighting: str, point_merge: bool,
                      force: bool):
    output_csv.parent.mkdir(parents=True, exist_ok=True)

    if output_csv.exists() and not force:
        print(f"[pv] reuse: {output_csv}")
        return

    cmd = [pvpython, "--mesa", ctg_script,
           "-i", str(input_vtu),
           "-o", str(output_csv),
           "--weighting", weighting]
    if point_merge:
        cmd.append("--point-merge")
    cmd += ["--arrays", *arrays]

    print("[pv] run:", " ".join(shlex.quote(c) for c in cmd))
    subprocess.run(cmd, check=True)
    print(f"[pv] wrote: {output_csv}")


# -------------------------- Cp plotting (the working logic) --------------------------
def plot_cp_from_paraview_csv(csv_in: Path, *,
                              vref: float, mu_col: str, sig_col: str | None,
                              z_strategy: str, round_decimals: int,
                              nbins: int, negate: bool, shade_std: bool,
                              refs: list[tuple[str, np.ndarray, np.ndarray]],
                              out_csv: Path, out_fig: Path):
    df = read_csv_any(csv_in)
    px, py, pz = _detect_point_cols(df.columns)

    if mu_col not in df.columns:
        raise KeyError(f"Missing '{mu_col}' in {csv_in}. Have: {list(df.columns)}")
    has_sig = (sig_col is not None and sig_col in df.columns)

    print(f"[load] csv={csv_in} rows={len(df)} cols={len(df.columns)}")
    print(f"[cols] coords=[{px},{py},{pz}] mu={mu_col} sig={sig_col if has_sig else 'None'}")

    # For now: either ignore z (none) or collapse by rounded (x,y) mean
    if z_strategy == "mean":
        df["_xr"] = df[px].round(round_decimals)
        df["_yr"] = df[py].round(round_decimals)
        agg = {px: "mean", py: "mean", pz: "mean", mu_col: "mean"}
        if has_sig:
            agg[sig_col] = "mean"
        g = df.groupby(["_xr", "_yr"], as_index=False).agg(agg)
        df = g
        print(f"[zmean] xy_unique={len(df)} round_decimals={round_decimals}")
    else:
        print(f"[z] strategy=none unique_z={df[pz].nunique()}")

    xy = df[[px, py]].to_numpy()
    le = xy[np.argmin(xy[:, 0])]
    te = xy[np.argmax(xy[:, 0])]
    chord = te - le
    c = float(np.linalg.norm(chord))
    t = chord / c
    n = np.array([-t[1], t[0]])

    rel = xy - le
    x_over_c = np.clip((rel @ t) / c, 0.0, 1.0)
    y_signed = rel @ n

    print(f"[chord] LE=({le[0]:.7f},{le[1]:.7f}) TE=({te[0]:.7f},{te[1]:.7f}) c={c:.10f}")

    q = 0.5 * vref * vref
    mu = df[mu_col].to_numpy(dtype=float) / q
    sig = df[sig_col].to_numpy(dtype=float) / q if has_sig else None

    # two curves only: per x-bin, choose max-y on upper, min-y on lower
    bins = np.linspace(0.0, 1.0, nbins + 1)
    ib = np.digitize(x_over_c, bins) - 1
    valid = (ib >= 0) & (ib < nbins)

    xv = x_over_c[valid]
    yv = y_signed[valid]
    mv = mu[valid]
    sv = sig[valid] if sig is not None else None
    ibv = ib[valid]

    up_rows, lo_rows = [], []
    for b in range(nbins):
        m = (ibv == b)
        if not np.any(m):
            continue
        xx = xv[m]; yy = yv[m]; mm = mv[m]
        ss = sv[m] if sv is not None else None

        is_up = (yy >= 0)
        is_lo = ~is_up

        if np.any(is_up):
            iu = np.argmax(yy[is_up])
            up_rows.append((float(xx[is_up][iu]), float(mm[is_up][iu]),
                            float(0.0 if ss is None else ss[is_up][iu])))
        if np.any(is_lo):
            il = np.argmin(yy[is_lo])
            lo_rows.append((float(xx[is_lo][il]), float(mm[is_lo][il]),
                            float(0.0 if ss is None else ss[is_lo][il])))

    up = np.array(up_rows, dtype=float)
    lo = np.array(lo_rows, dtype=float)
    up = up[np.argsort(up[:, 0])]
    lo = lo[np.argsort(lo[:, 0])]

    print(f"[envelope] x_bins={nbins} upper_pts={len(up)} lower_pts={len(lo)}")

    # write processed curve CSV
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame({
        "side": ["upper"] * len(up) + ["lower"] * len(lo),
        "x_over_c": np.concatenate([up[:, 0], lo[:, 0]]),
        "Cp": np.concatenate([up[:, 1], lo[:, 1]]),
        "Cp_std": np.concatenate([up[:, 2], lo[:, 2]]),
    }).to_csv(out_csv, index=False)
    print(f"[write] csv_out={out_csv}")

    # plot
    out_fig.parent.mkdir(parents=True, exist_ok=True)
    plt.figure(figsize=(10, 5.2))
    yfac = -1.0 if negate else 1.0

    plt.plot(up[:, 0], yfac * up[:, 1], label="upper")
    plt.plot(lo[:, 0], yfac * lo[:, 1], label="lower")

    if shade_std and sig is not None:
        plt.fill_between(up[:, 0], yfac * (up[:, 1] - up[:, 2]), yfac * (up[:, 1] + up[:, 2]), alpha=0.15)
        plt.fill_between(lo[:, 0], yfac * (lo[:, 1] - lo[:, 2]), yfac * (lo[:, 1] + lo[:, 2]), alpha=0.15)

    # overlay refs (assumed already in same ordinate, typically -Cp)
    for lbl, rx, ry in refs:
        plt.scatter(rx, ry, s=1, linewidths=1.0, label=lbl)

    plt.xlim(0.0, 1.0)
    plt.xlabel(r"$x/c$")
    plt.ylabel(r"$-C_p$" if negate else r"$C_p$")
    plt.grid(True, which="both")
    plt.legend(frameon=False, ncol=2 if len(refs) >= 3 else 1)
    plt.tight_layout()
    plt.savefig(out_fig, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"[plot] fig_out={out_fig}")


# -------------------------- config driver --------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ini", help="INI file containing postprocess-paraview-* sections")
    ap.add_argument("section", help="Section to run, e.g. postprocess-paraview-Cp")
    ap.add_argument("--force", action="store_true", help="Re-run pvpython even if CSV exists")
    args = ap.parse_args()

    cfg = configparser.ConfigParser()
    cfg.optionxform = str  # preserve case
    cfg.read(args.ini)

    if args.section not in cfg:
        raise SystemExit(f"[cfg] missing section: {args.section}")

    sect = cfg[args.section]
    family = args.section.split("-", 2)[1]  # paraview
    base_name = f"postprocess-{family}-base"
    base = cfg[base_name] if base_name in cfg else {}

    const_env = eval_constants(cfg)

    def inherit(key: str, default: str = "") -> str:
        return sect.get(key, base.get(key, default))

    # --- pv extraction inputs ---
    pvpython = inherit("pvpython", "/mnt/share/sambit98/.downloads/ParaView-5.13.0/bin/pvpython")
    ctg_script = inherit("ctg-script", "/mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/simulation-automations/pvtocsv.py")
    input_vtu = Path(inherit("src-vtu", inherit("src-file"))).resolve()
    ctg_csv = Path(inherit("ctg-csv", "./postprocess/tavgs-ctg.csv")).resolve()

    arrays = inherit("arrays", "Avg-P Std-P").split()
    weighting = inherit("weighting", "average_by_number")
    point_merge = inherit("point-merge", "true").lower() in ("1", "true", "yes", "on")

    # --- plotting inputs ---
    mu_col = inherit("mu-col", "Avg-P")
    sig_col = inherit("sig-col", "Std-P")
    z_strategy = inherit("z-strategy", "none")  # none | mean
    round_decimals = int(inherit("round-decimals", "8"))
    nbins = int(inherit("nbins", "600"))
    negate = inherit("negate", "true").lower() in ("1", "true", "yes", "on")
    shade_std = inherit("shade-std", "true").lower() in ("1", "true", "yes", "on")

    vref_expr = inherit("vref", "Uin")
    vref = float(eval(vref_expr, {"__builtins__": {}}, const_env))

    out_csv = Path(inherit("out-csv", "./postprocess/cp_2d.csv")).resolve()
    out_fig = Path(inherit("out-fig", "./postprocess/cp.png")).resolve()

    ref_spec = inherit("reference", "")
    refs = load_reference_csvs(ref_spec)

    print(f"\n[cfg] section={args.section}")
    print(f"[cfg] input_vtu={input_vtu}")
    print(f"[cfg] ctg_csv={ctg_csv}")
    print(f"[cfg] arrays={arrays} weighting={weighting} point_merge={point_merge}")
    print(f"[cfg] vref={vref:.6g} (expr='{vref_expr}') negate={negate} shade_std={shade_std}")
    print(f"[cfg] out_csv={out_csv}")
    print(f"[cfg] out_fig={out_fig}")

    # 1) pvpython clean-to-grid -> CSV
    run_clean_to_grid(
        pvpython=pvpython, ctg_script=ctg_script,
        input_vtu=input_vtu, output_csv=ctg_csv,
        arrays=arrays, weighting=weighting, point_merge=point_merge,
        force=args.force
    )

    # 2) plot Cp with refs
    plot_cp_from_paraview_csv(
        ctg_csv,
        vref=vref, mu_col=mu_col, sig_col=sig_col,
        z_strategy=z_strategy, round_decimals=round_decimals,
        nbins=nbins, negate=negate, shade_std=shade_std,
        refs=refs,
        out_csv=out_csv, out_fig=out_fig
    )


if __name__ == "__main__":
    main()
