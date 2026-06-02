#!/usr/bin/env python3
"""Summarise PyFR implicit dtstats step and stage CSV files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd


def q(s, ps=(0.0, 0.25, 0.5, 0.75, 0.95, 0.99, 1.0)):
    s = pd.to_numeric(s, errors="coerce").dropna()
    if s.empty:
        return {}
    return {str(p): float(s.quantile(p)) for p in ps}


def safe_float(x):
    try:
        if pd.isna(x):
            return None
        return float(x)
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=Path, required=True,
                    help="dtstats step CSV, usually dtstats_fdw.csv")
    ap.add_argument("--stages", type=Path, default=None,
                    help="dtstats stage CSV, usually dtstats-stages.csv")
    ap.add_argument("--newton-max", type=int, default=None,
                    help="newton-max-iter from ground-truth config")
    ap.add_argument("--out", type=Path, default=None,
                    help="write markdown summary here")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    steps = pd.read_csv(args.steps)
    for c in ["n", "t", "dt", "wtime", "error"]:
        if c in steps:
            steps[c] = pd.to_numeric(steps[c], errors="coerce")

    accepted = steps[steps["action"].astype(str) == "accept"]
    rejected = steps[steps["action"].astype(str) == "reject"]
    phys = float(accepted["dt"].sum()) if len(accepted) else 0.0
    wall = float(accepted["wtime"].sum()) if "wtime" in accepted else 0.0

    out = {
        "step_file": str(args.steps),
        "n_rows": int(len(steps)),
        "n_accept": int(len(accepted)),
        "n_reject": int(len(rejected)),
        "t_min": safe_float(steps["t"].min()),
        "t_max_start": safe_float(steps["t"].max()),
        "accepted_physical_time_sum": phys,
        "accepted_wall_time_sum": wall,
        "wall_time_per_physical_time": wall / phys if phys > 0 else None,
        "dt_quantiles": q(accepted["dt"] if len(accepted) else steps["dt"]),
        "wtime_quantiles": q(accepted["wtime"] if len(accepted) else steps["wtime"]),
    }

    if args.stages:
        st = pd.read_csv(args.stages)
        for c in st.columns:
            if c != "precond_built":
                st[c] = pd.to_numeric(st[c], errors="coerce")
        st["precond_built_bool"] = st["precond_built"].astype(str).str.lower().isin(
            ["1", "true", "yes"]
        )
        st["resid_ratio"] = st["final_resid"] / st["init_resid"].replace(0, np.nan)
        st["krylov_per_newton"] = st["krylov_iters"] / st["newton_iters"].replace(0, np.nan)

        sout = {
            "stage_file": str(args.stages),
            "n_stage_rows": int(len(st)),
            "stages_per_step_median": safe_float(st.groupby("n").size().median()),
            "newton_iters_quantiles": q(st["newton_iters"]),
            "krylov_iters_quantiles": q(st["krylov_iters"]),
            "krylov_per_newton_quantiles": q(st["krylov_per_newton"]),
            "init_resid_quantiles": q(st["init_resid"]),
            "final_resid_quantiles": q(st["final_resid"]),
            "resid_ratio_quantiles": q(st["resid_ratio"]),
            "krylov_tol_quantiles": q(st["krylov_tol"]),
            "precond_apps_sum": int(st["precond_apps"].fillna(0).sum()),
            "precond_builds": int(st["precond_built_bool"].sum()),
            "precond_gdt_ratio_quantiles": q(st["precond_gdt_ratio"]),
        }
        if args.newton_max is not None:
            sout["newton_cap_fraction"] = float((st["newton_iters"] >= args.newton_max).mean())
        out["stages"] = sout

    if args.json:
        text = json.dumps(out, indent=2)
    else:
        lines = ["# PyFR implicit CSV summary", ""]
        lines += [
            f"step_file: {out['step_file']}",
            f"rows: {out['n_rows']}",
            f"accepted: {out['n_accept']}",
            f"rejected: {out['n_reject']}",
            f"accepted_physical_time_sum: {out['accepted_physical_time_sum']:.12g}",
            f"accepted_wall_time_sum: {out['accepted_wall_time_sum']:.12g}",
            f"wall_time_per_physical_time: {out['wall_time_per_physical_time']}",
            f"dt_quantiles: {out['dt_quantiles']}",
            f"wtime_quantiles: {out['wtime_quantiles']}",
        ]
        if "stages" in out:
            s = out["stages"]
            lines += ["", "## Stage diagnostics"]
            for k, v in s.items():
                lines.append(f"{k}: {v}")
        text = "\n".join(lines) + "\n"

    if args.out:
        args.out.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
