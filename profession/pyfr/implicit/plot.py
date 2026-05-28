#!/usr/bin/env python3
"""
pyfr_implicit_diag.py

Single-file diagnostic plotting utility for PyFR implicit runs.

Inputs:
  1. PyFR ini file
  2. dtstats CSV from [soln-plugin-dtstats]
  3. stage-file CSV from [soln-plugin-dtstats]

Example:
  python3 pyfr_implicit_diag.py \
      --ini c1.ini \
      --dtstats dtstats_fdw.csv \
      --stages dtstats-stages.csv \
      --outdir diag_pi

Expected CSV columns:

dtstats:
  n,t,dt,action,wtime,error

stage file:
  n,stage,newton_iters,krylov_iters,precond_apps,
  init_resid,final_resid,krylov_tol,precond_gdt_ratio,precond_built
"""

from __future__ import annotations

import argparse
import configparser
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


# -----------------------------------------------------------------------------
# Plot style
# -----------------------------------------------------------------------------

plt.rcParams.update({
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "axes.titlesize": 17,
    "axes.labelsize": 15,
    "xtick.labelsize": 12,
    "ytick.labelsize": 12,
    "legend.fontsize": 10,
    "lines.linewidth": 2.0,
    "axes.grid": True,
    "grid.alpha": 0.30,
})


# -----------------------------------------------------------------------------
# Small utilities
# -----------------------------------------------------------------------------

def read_csv_clean(path: Path) -> pd.DataFrame:
    """Read a CSV and coerce numeric-looking columns to numeric."""
    if not path.exists():
        raise FileNotFoundError(path)

    df = pd.read_csv(path, comment="#", skip_blank_lines=True)
    df.columns = [c.strip() for c in df.columns]

    for c in df.columns:
        if df[c].dtype == object:
            df[c] = df[c].astype(str).str.strip()
            df[c] = df[c].replace({"": np.nan, "None": np.nan, "none": np.nan})
            maybe = pd.to_numeric(df[c], errors="coerce")
            # Convert if at least some values are numeric, but preserve action strings.
            if maybe.notna().sum() > 0 and c not in {"action"}:
                df[c] = maybe

    return df


def read_ini(path: Path | None) -> configparser.ConfigParser:
    cfg = configparser.ConfigParser(
        inline_comment_prefixes=(";", "#"),
        interpolation=None,
    )
    cfg.optionxform = str

    if path is not None:
        if not path.exists():
            raise FileNotFoundError(path)
        cfg.read(path)

    return cfg


def cfg_get(cfg: configparser.ConfigParser, section: str, key: str, default: str = "") -> str:
    if cfg.has_section(section):
        for k in cfg[section]:
            if k.lower() == key.lower():
                return str(cfg[section][k]).strip()
    return default


def cfg_float(cfg: configparser.ConfigParser, section: str, key: str, default=np.nan) -> float:
    txt = cfg_get(cfg, section, key, "")
    if not txt:
        return default
    try:
        return float(eval(txt, {"__builtins__": {}}, {}))
    except Exception:
        return default


def cfg_int(cfg: configparser.ConfigParser, section: str, key: str, default=-1) -> int:
    val = cfg_float(cfg, section, key, np.nan)
    return default if not np.isfinite(val) else int(val)


def ensure_outdir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def savefig(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    plt.tight_layout()
    plt.savefig(path, bbox_inches="tight")
    plt.close()
    print(f"[pyfr-implicit-diag] saved {path}")


def rolling_median(y: pd.Series | np.ndarray, window: int) -> np.ndarray:
    y = pd.Series(y)
    if len(y) < 3:
        return y.to_numpy()
    window = max(3, min(window, len(y)))
    if window % 2 == 0:
        window += 1
    return y.rolling(window, center=True, min_periods=1).median().to_numpy()


def numeric_col(df: pd.DataFrame, name: str, default=np.nan) -> pd.Series:
    if name not in df:
        return pd.Series(default, index=df.index, dtype=float)
    return pd.to_numeric(df[name], errors="coerce")


def bool_col(df: pd.DataFrame, name: str) -> pd.Series:
    if name not in df:
        return pd.Series(False, index=df.index)
    s = df[name]
    if s.dtype == bool:
        return s
    return s.astype(str).str.strip().str.lower().isin({"true", "1", "yes", "y"})


# -----------------------------------------------------------------------------
# Config summary
# -----------------------------------------------------------------------------

def config_summary(cfg: configparser.ConfigParser) -> dict[str, str]:
    sti = "solver-time-integrator"

    keys = [
        ("backend", "precision"),
        ("backend", "memory-model"),
        ("solver", "system"),
        ("solver", "order"),
        (sti, "formulation"),
        (sti, "scheme"),
        (sti, "controller"),
        (sti, "tstart"),
        (sti, "dt"),
        (sti, "tend"),
        (sti, "dt-min"),
        (sti, "dt-max"),
        (sti, "atol"),
        (sti, "rtol"),
        (sti, "krylov-solver"),
        (sti, "krylov-max-iter"),
        (sti, "krylov-rtol"),
        (sti, "krylov-precond"),
        (sti, "krylov-precond-dtype"),
        (sti, "gmres-arnoldi"),
        (sti, "newton-rtol"),
        (sti, "newton-max-iter"),
        (sti, "tput-limit"),
    ]

    out = {}
    for sec, key in keys:
        val = cfg_get(cfg, sec, key, "")
        if val:
            out[f"{sec}.{key}"] = val
    return out


def plot_config_card(cfg: configparser.ConfigParser, outdir: Path, case_name: str):
    summary = config_summary(cfg)
    if not summary:
        return

    lines = [case_name, ""]
    for k, v in summary.items():
        lines.append(f"{k} = {v}")

    text = "\n".join(lines)

    plt.figure(figsize=(11, 7))
    plt.axis("off")
    plt.text(
        0.02, 0.98, text,
        va="top", ha="left",
        family="monospace",
        fontsize=10,
    )
    savefig(outdir / "00_config_card.png")


# -----------------------------------------------------------------------------
# Attach physical time to stage rows
# -----------------------------------------------------------------------------

def attach_stage_time(dtstats: pd.DataFrame, stages: pd.DataFrame) -> pd.DataFrame:
    """
    Stage file n is usually accepted-step index. dtstats n can be attempt index
    when rejections are present. This function first maps stages to accepted
    rows by accepted-step count. If that fails, it falls back to direct n.
    """
    st = stages.copy()

    if "action" in dtstats:
        accepted = dtstats[dtstats["action"].astype(str).str.lower() == "accept"].copy()
    else:
        accepted = dtstats.copy()

    accepted = accepted.reset_index(drop=True)
    accepted["accepted_step"] = np.arange(len(accepted), dtype=int)

    keep = ["accepted_step", "n", "t", "dt", "wtime", "error"]
    keep = [c for c in keep if c in accepted.columns]
    acc_map = accepted[keep].copy()

    merged = st.merge(
        acc_map.drop(columns=["n"], errors="ignore"),
        left_on="n",
        right_on="accepted_step",
        how="left",
        suffixes=("", "_dtstats"),
    )

    coverage = merged["t"].notna().mean() if "t" in merged else 0.0

    if coverage < 0.50 and "n" in dtstats.columns:
        # Fallback: direct merge using the CSV n column.
        keep2 = ["n", "t", "dt", "wtime", "error"]
        keep2 = [c for c in keep2 if c in dtstats.columns]
        merged = st.merge(
            dtstats[keep2],
            on="n",
            how="left",
            suffixes=("", "_dtstats"),
        )
        merged["accepted_step"] = merged["n"]

    if "t" not in merged or merged["t"].isna().all():
        merged["t"] = merged["n"].astype(float)

    return merged


# -----------------------------------------------------------------------------
# dtstats plots
# -----------------------------------------------------------------------------

def plot_dt_vs_attempt(dt: pd.DataFrame, outdir: Path, case_name: str):
    idx = np.arange(len(dt))
    action = dt["action"].astype(str).str.lower() if "action" in dt else pd.Series("accept", index=dt.index)
    is_acc = action == "accept"
    is_rej = action == "reject"

    y = numeric_col(dt, "dt")

    plt.figure(figsize=(10, 5))
    plt.semilogy(idx[is_acc], y[is_acc], ".", label="accept", markersize=5)
    if is_rej.any():
        plt.semilogy(idx[is_rej], y[is_rej], "x", label="reject", markersize=5)
    plt.xlabel("attempt index")
    plt.ylabel("dt")
    plt.title(f"{case_name}: time step attempts")
    plt.legend(frameon=False)
    savefig(outdir / "01_dt_vs_attempt.png")


def plot_error_vs_attempt(dt: pd.DataFrame, outdir: Path, case_name: str):
    if "error" not in dt:
        return

    idx = np.arange(len(dt))
    action = dt["action"].astype(str).str.lower() if "action" in dt else pd.Series("accept", index=dt.index)
    is_acc = action == "accept"
    is_rej = action == "reject"

    err = numeric_col(dt, "error")
    ok = err.notna() & np.isfinite(err)

    if ok.sum() == 0:
        return

    plt.figure(figsize=(10, 5))
    plt.semilogy(idx[ok & is_acc], err[ok & is_acc], ".", label="accept", markersize=5)
    if is_rej.any():
        plt.semilogy(idx[ok & is_rej], err[ok & is_rej], "x", label="reject", markersize=5)
    plt.axhline(1.0, color="k", linestyle="--", linewidth=1.5, label="accept/reject threshold")
    plt.xlabel("attempt index")
    plt.ylabel("normalized error")
    plt.title(f"{case_name}: adaptive-controller error")
    plt.legend(frameon=False)
    savefig(outdir / "02_error_vs_attempt.png")


def plot_dt_vs_time_accepts(dt: pd.DataFrame, outdir: Path, case_name: str):
    action = dt["action"].astype(str).str.lower() if "action" in dt else pd.Series("accept", index=dt.index)
    acc = dt[action == "accept"].copy()
    if acc.empty or "t" not in acc or "dt" not in acc:
        return

    plt.figure(figsize=(10, 5))
    plt.plot(acc["t"], acc["dt"], ".", markersize=4, label="accepted dt")
    med = rolling_median(acc["dt"], window=max(5, len(acc) // 40))
    plt.plot(acc["t"], med, linewidth=2.5, label="rolling median")
    plt.xlabel("physical time")
    plt.ylabel("accepted dt")
    plt.title(f"{case_name}: accepted dt vs physical time")
    plt.legend(frameon=False)
    savefig(outdir / "03_dt_vs_time_accepts.png")


def plot_wtime_vs_attempt(dt: pd.DataFrame, outdir: Path, case_name: str):
    if "wtime" not in dt:
        return

    idx = np.arange(len(dt))
    wt = numeric_col(dt, "wtime")
    action = dt["action"].astype(str).str.lower() if "action" in dt else pd.Series("accept", index=dt.index)
    is_acc = action == "accept"
    is_rej = action == "reject"

    plt.figure(figsize=(10, 5))
    plt.plot(idx[is_acc], wt[is_acc], ".", markersize=4, label="accept")
    if is_rej.any():
        plt.plot(idx[is_rej], wt[is_rej], "x", markersize=5, label="reject")
    med = rolling_median(wt, window=max(5, len(wt) // 50))
    plt.plot(idx, med, linewidth=2.5, label="rolling median")
    plt.xlabel("attempt index")
    plt.ylabel("wall time per attempt [s]")
    plt.title(f"{case_name}: wall time per attempt")
    plt.legend(frameon=False)
    savefig(outdir / "04_wtime_vs_attempt.png")


def plot_cost_per_physical_time(dt: pd.DataFrame, outdir: Path, case_name: str):
    if not {"dt", "wtime"}.issubset(dt.columns):
        return

    action = dt["action"].astype(str).str.lower() if "action" in dt else pd.Series("accept", index=dt.index)
    acc = dt[action == "accept"].copy()
    if acc.empty:
        return

    acc["cost_per_time"] = numeric_col(acc, "wtime") / numeric_col(acc, "dt")
    acc["cum_wall"] = numeric_col(acc, "wtime").cumsum()

    plt.figure(figsize=(10, 5))
    plt.semilogy(acc["t"], acc["cost_per_time"], ".", markersize=4, label="wtime/dt")
    med = rolling_median(acc["cost_per_time"], window=max(5, len(acc) // 40))
    plt.semilogy(acc["t"], med, linewidth=2.5, label="rolling median")
    plt.xlabel("physical time")
    plt.ylabel("wall seconds per physical-time unit")
    plt.title(f"{case_name}: cost per physical time")
    plt.legend(frameon=False)
    savefig(outdir / "20_cost_per_physical_time.png")

    plt.figure(figsize=(10, 5))
    plt.plot(acc["t"], acc["cum_wall"], linewidth=2.5)
    plt.xlabel("physical time")
    plt.ylabel("cumulative accepted-step wall time [s]")
    plt.title(f"{case_name}: cumulative accepted-step cost")
    savefig(outdir / "21_cumulative_walltime.png")


# -----------------------------------------------------------------------------
# Stage plots
# -----------------------------------------------------------------------------

def plot_stage_quantity(
    st: pd.DataFrame,
    outdir: Path,
    case_name: str,
    ycol: str,
    ylabel: str,
    filename: str,
    hline: float | None = None,
    logy: bool = False,
):
    if ycol not in st:
        return

    x = numeric_col(st, "t")
    y = numeric_col(st, ycol)

    plt.figure(figsize=(10, 5))
    if "stage" in st:
        for stage_id, sub in st.groupby("stage"):
            xs = numeric_col(sub, "t")
            ys = numeric_col(sub, ycol)
            if logy:
                plt.semilogy(xs, ys, ".", markersize=4, label=f"stage {stage_id}")
            else:
                plt.plot(xs, ys, ".", markersize=4, label=f"stage {stage_id}")
    else:
        if logy:
            plt.semilogy(x, y, ".", markersize=4)
        else:
            plt.plot(x, y, ".", markersize=4)

    if hline is not None and np.isfinite(hline):
        plt.axhline(hline, color="k", linestyle="--", linewidth=1.5, label=f"limit = {hline:g}")

    plt.xlabel("physical time")
    plt.ylabel(ylabel)
    plt.title(f"{case_name}: {ylabel}")
    plt.legend(frameon=False, ncol=2)
    savefig(outdir / filename)


def plot_residual_reduction(st: pd.DataFrame, outdir: Path, case_name: str):
    needed = {"init_resid", "final_resid"}
    if not needed.issubset(st.columns):
        return

    init = numeric_col(st, "init_resid")
    final = numeric_col(st, "final_resid")
    ratio = final / init
    ratio = ratio.replace([np.inf, -np.inf], np.nan)

    tmp = st.copy()
    tmp["resid_ratio"] = ratio

    plot_stage_quantity(
        tmp, outdir, case_name,
        ycol="resid_ratio",
        ylabel="final_resid / init_resid",
        filename="12_residual_reduction.png",
        logy=True,
    )

    plt.figure(figsize=(10, 5))
    x = numeric_col(st, "t")
    plt.semilogy(x, init, ".", markersize=4, label="init_resid")
    plt.semilogy(x, final, ".", markersize=4, label="final_resid")
    plt.xlabel("physical time")
    plt.ylabel("residual norm")
    plt.title(f"{case_name}: nonlinear residuals")
    plt.legend(frameon=False)
    savefig(outdir / "12b_residual_norms.png")


def plot_krylov_per_newton(st: pd.DataFrame, outdir: Path, case_name: str):
    if not {"newton_iters", "krylov_iters"}.issubset(st.columns):
        return

    newt = numeric_col(st, "newton_iters")
    kry = numeric_col(st, "krylov_iters")
    ratio = kry / newt.replace(0, np.nan)

    tmp = st.copy()
    tmp["krylov_per_newton"] = ratio

    plot_stage_quantity(
        tmp, outdir, case_name,
        ycol="krylov_per_newton",
        ylabel="GMRES iterations per Newton iteration",
        filename="13_krylov_per_newton.png",
        logy=False,
    )


def plot_preconditioner(st: pd.DataFrame, outdir: Path, case_name: str):
    has_ratio = "precond_gdt_ratio" in st
    has_built = "precond_built" in st

    if not has_ratio and not has_built:
        return

    plt.figure(figsize=(10, 5))

    if has_ratio:
        x = numeric_col(st, "t")
        y = numeric_col(st, "precond_gdt_ratio")
        plt.plot(x, y, ".", markersize=4, label="precond_gdt_ratio")
        plt.axhline(1.0, color="k", linestyle="--", linewidth=1.5, label="ideal = 1")

    if has_built:
        built = bool_col(st, "precond_built")
        if built.any():
            xb = numeric_col(st.loc[built], "t")
            if has_ratio:
                yb = numeric_col(st.loc[built], "precond_gdt_ratio")
            else:
                yb = np.ones(len(xb))
            plt.plot(xb, yb, "x", markersize=7, label="preconditioner rebuilt")

    plt.xlabel("physical time")
    plt.ylabel("preconditioner diagnostic")
    plt.title(f"{case_name}: preconditioner reuse/rebuild")
    plt.legend(frameon=False)
    savefig(outdir / "14_preconditioner.png")


# -----------------------------------------------------------------------------
# Text summary and recommendations
# -----------------------------------------------------------------------------

def summarize(dt: pd.DataFrame, st: pd.DataFrame, cfg: configparser.ConfigParser) -> list[str]:
    lines: list[str] = []

    sti = "solver-time-integrator"

    formulation = cfg_get(cfg, sti, "formulation", "?")
    scheme = cfg_get(cfg, sti, "scheme", "?")
    controller = cfg_get(cfg, sti, "controller", "?")
    ini_dt = cfg_get(cfg, sti, "dt", "?")
    atol = cfg_get(cfg, sti, "atol", "?")
    rtol = cfg_get(cfg, sti, "rtol", "?")
    krtol = cfg_get(cfg, sti, "krylov-rtol", "?")
    nmax = cfg_int(cfg, sti, "newton-max-iter", -1)
    kmax = cfg_int(cfg, sti, "krylov-max-iter", -1)

    lines.append("PyFR implicit diagnostic summary")
    lines.append("=" * 38)
    lines.append("")
    lines.append("Config")
    lines.append(f"  formulation        = {formulation}")
    lines.append(f"  scheme             = {scheme}")
    lines.append(f"  controller         = {controller}")
    lines.append(f"  ini dt             = {ini_dt}")
    lines.append(f"  atol, rtol         = {atol}, {rtol}")
    lines.append(f"  krylov-rtol        = {krtol}")
    lines.append(f"  newton-max-iter    = {nmax if nmax >= 0 else '?'}")
    lines.append(f"  krylov-max-iter    = {kmax if kmax >= 0 else '?'}")
    lines.append("")

    # dtstats summary
    action = dt["action"].astype(str).str.lower() if "action" in dt else pd.Series("accept", index=dt.index)
    acc = dt[action == "accept"].copy()
    rej = dt[action == "reject"].copy()

    lines.append("dtstats")
    lines.append(f"  attempts           = {len(dt)}")
    lines.append(f"  accepted           = {len(acc)}")
    lines.append(f"  rejected           = {len(rej)}")

    if len(dt):
        lines.append(f"  rejection fraction = {len(rej) / len(dt):.4f}")

    if not acc.empty:
        acc_dt = numeric_col(acc, "dt")
        lines.append(f"  first accepted dt  = {acc_dt.iloc[0]:.8e}")
        lines.append(f"  min accepted dt    = {acc_dt.min():.8e}")
        lines.append(f"  median accepted dt = {acc_dt.median():.8e}")
        lines.append(f"  max accepted dt    = {acc_dt.max():.8e}")

        if "error" in acc:
            err = numeric_col(acc, "error").dropna()
            if len(err):
                lines.append(f"  median error       = {err.median():.6g}")
                lines.append(f"  p95 error          = {err.quantile(0.95):.6g}")
                lines.append(f"  max error          = {err.max():.6g}")

        if "wtime" in acc:
            wt = numeric_col(acc, "wtime").dropna()
            if len(wt):
                warm = max(1, int(0.05 * len(wt)))
                wt2 = wt.iloc[warm:]
                lines.append(f"  median wtime       = {wt2.median():.6g} s")
                lines.append(f"  p95 wtime          = {wt2.quantile(0.95):.6g} s")

    lines.append("")

    # Stage summary
    lines.append("stage file")
    lines.append(f"  rows               = {len(st)}")

    if "stage" in st:
        lines.append(f"  stages seen        = {sorted(pd.unique(st['stage']))}")

    if "newton_iters" in st:
        ni = numeric_col(st, "newton_iters").dropna()
        if len(ni):
            lines.append(f"  median Newton      = {ni.median():.3g}")
            lines.append(f"  p95 Newton         = {ni.quantile(0.95):.3g}")
            lines.append(f"  max Newton         = {ni.max():.3g}")
            if nmax > 0:
                hits = int((ni >= nmax).sum())
                lines.append(f"  Newton cap hits    = {hits}")

    if "krylov_iters" in st:
        ki = numeric_col(st, "krylov_iters").dropna()
        if len(ki):
            lines.append(f"  median Krylov      = {ki.median():.3g}")
            lines.append(f"  p95 Krylov         = {ki.quantile(0.95):.3g}")
            lines.append(f"  max Krylov         = {ki.max():.3g}")
            if kmax > 0:
                hits = int((ki >= kmax).sum())
                lines.append(f"  Krylov cap hits    = {hits}")

    if {"init_resid", "final_resid"}.issubset(st.columns):
        ratio = numeric_col(st, "final_resid") / numeric_col(st, "init_resid")
        ratio = ratio.replace([np.inf, -np.inf], np.nan).dropna()
        if len(ratio):
            lines.append(f"  median resid ratio = {ratio.median():.6g}")
            lines.append(f"  p95 resid ratio    = {ratio.quantile(0.95):.6g}")
            lines.append(f"  max resid ratio    = {ratio.max():.6g}")

    if "precond_built" in st:
        built = bool_col(st, "precond_built")
        lines.append(f"  precond rebuilds   = {int(built.sum())}")

    lines.append("")
    lines.append("tuning hints")
    lines.append("  - If many initial rejections occur, set initial dt near the first accepted dt.")
    lines.append("  - If accepted error is far below 1 for a long time, dt-max or PI growth may be limiting.")
    lines.append("  - If Newton reaches newton-max-iter, reduce dt or use a more robust startup setting.")
    lines.append("  - If Krylov reaches krylov-max-iter, improve the preconditioner or loosen/tune krylov-rtol.")
    lines.append("  - If residual ratio is not clearly below 1, Newton is not reducing the nonlinear residual.")
    lines.append("  - If precond_gdt_ratio drifts far from 1, the reused preconditioner may be stale.")

    # Specific automated suggestions.
    lines.append("")
    lines.append("automated suggestions")

    if len(rej) > 0 and not acc.empty:
        first_acc_dt = numeric_col(acc, "dt").iloc[0]
        lines.append(f"  set initial dt approximately {first_acc_dt:.8e}")

    if controller.lower() == "pi":
        lines.append("  PI is working if accepted errors remain below 1 and dt grows smoothly.")
        lines.append("  Keep tput-limit = false if the throughput limiter crashes in PR555.")

    if "newton_iters" in st and nmax > 0:
        ni = numeric_col(st, "newton_iters").dropna()
        if len(ni) and (ni >= nmax).any():
            lines.append("  Newton cap was reached: reduce dt-max or use a smaller starting dt.")

    if "krylov_iters" in st and kmax > 0:
        ki = numeric_col(st, "krylov_iters").dropna()
        if len(ki) and (ki >= kmax).any():
            lines.append("  Krylov cap was reached: raise krylov-max-iter or improve preconditioning.")

    return lines


def write_summary(dt: pd.DataFrame, st: pd.DataFrame, cfg: configparser.ConfigParser, outdir: Path):
    lines = summarize(dt, st, cfg)
    path = outdir / "summary.txt"
    path.write_text("\n".join(lines) + "\n")
    print(f"[pyfr-implicit-diag] wrote {path}")
    print("")
    print("\n".join(lines))


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Plot PyFR implicit dtstats and Newton/GMRES stage diagnostics.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    ap.add_argument("--ini", type=Path, default=None, help="PyFR config ini file")
    ap.add_argument("--dtstats", type=Path, required=True, help="dtstats CSV")
    ap.add_argument("--stages", type=Path, required=True, help="stage-file CSV")
    ap.add_argument("--outdir", type=Path, default=Path("implicit_diag"), help="output directory")
    ap.add_argument("--case-name", default="", help="optional label for plot titles")
    args = ap.parse_args(argv)

    outdir = ensure_outdir(args.outdir)

    cfg = read_ini(args.ini)
    dt = read_csv_clean(args.dtstats)
    stages = read_csv_clean(args.stages)
    st = attach_stage_time(dt, stages)

    # Infer case label.
    if args.case_name:
        case_name = args.case_name
    else:
        scheme = cfg_get(cfg, "solver-time-integrator", "scheme", "")
        controller = cfg_get(cfg, "solver-time-integrator", "controller", "")
        order = cfg_get(cfg, "solver", "order", "")
        bits = []
        if order:
            bits.append(f"P{order}")
        if scheme:
            bits.append(scheme)
        if controller:
            bits.append(controller)
        case_name = " ".join(bits) if bits else args.dtstats.stem

    # Write normalized copies for easy inspection.
    dt.to_csv(outdir / "normalized_dtstats.csv", index=False)
    st.to_csv(outdir / "normalized_stages_with_time.csv", index=False)

    # Config card.
    plot_config_card(cfg, outdir, case_name)

    # dtstats plots.
    plot_dt_vs_attempt(dt, outdir, case_name)
    plot_error_vs_attempt(dt, outdir, case_name)
    plot_dt_vs_time_accepts(dt, outdir, case_name)
    plot_wtime_vs_attempt(dt, outdir, case_name)
    plot_cost_per_physical_time(dt, outdir, case_name)

    # Stage plots.
    nmax = cfg_int(cfg, "solver-time-integrator", "newton-max-iter", -1)
    kmax = cfg_int(cfg, "solver-time-integrator", "krylov-max-iter", -1)

    plot_stage_quantity(
        st, outdir, case_name,
        ycol="newton_iters",
        ylabel="Newton iterations",
        filename="10_newton_iters.png",
        hline=float(nmax) if nmax > 0 else None,
        logy=False,
    )

    plot_stage_quantity(
        st, outdir, case_name,
        ycol="krylov_iters",
        ylabel="GMRES/Krylov iterations",
        filename="11_krylov_iters.png",
        hline=float(kmax) if kmax > 0 else None,
        logy=False,
    )

    plot_stage_quantity(
        st, outdir, case_name,
        ycol="precond_apps",
        ylabel="preconditioner applications",
        filename="11b_precond_apps.png",
        hline=None,
        logy=False,
    )

    plot_residual_reduction(st, outdir, case_name)
    plot_krylov_per_newton(st, outdir, case_name)
    plot_preconditioner(st, outdir, case_name)

    # Summary.
    write_summary(dt, st, cfg, outdir)


if __name__ == "__main__":
    main()