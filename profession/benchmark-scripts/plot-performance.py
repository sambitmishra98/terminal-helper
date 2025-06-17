#!/usr/bin/env python3
from __future__ import annotations
import argparse
import math
import re
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt


def parse_args() -> Path:
    p = argparse.ArgumentParser(
        description="Generate DoF/s vs DoF plots from postprocessed csv"
    )
    p.add_argument("csv", type=Path,
        help="CSV file produced by `pyfr benchmark postprocess …`",
    )
    args = p.parse_args()
    if not args.csv.exists():
        p.error(f"CSV file '{args.csv}' not found")

    return args.csv.resolve()

def deduce_element_type(df: pd.DataFrame) -> None:
    """
    Add df['etype'] by inspecting which stats:mesh_nelems-* column is
    *present* (i.e. non-NaN) in each row.

    Works whether the entry holds a single integer or a quoted list such
    as "108,113,111,…".
    """
    nelem_cols = [c for c in df.columns if c.startswith("stats:mesh_nelems-")]
    if not nelem_cols:
        raise RuntimeError("No 'stats:mesh_nelems-*' columns present in CSV")

    def _row_etype(row):
        present = [c for c in nelem_cols if not pd.isna(row[c])]
        if len(present) != 1:
            raise ValueError(
                f"Row '{row['file-name']}' has {len(present)} populated "
                f"'mesh_nelems-*' columns (expected exactly 1).")
        return present[0].split("-")[-1]      # stats:mesh_nelems-hex → hex

    df["etype"] = df.apply(_row_etype, axis=1)

_STAGE_MAP = {"euler": 1, "rk2": 2, "rk3": 3, "rk4": 4, "rk45": 5,}

def add_stage_count(df: pd.DataFrame) -> None:
    """
    Adds df['nstages'] by looking up config:solver-time-integrator_scheme.
    Raises if an unknown scheme is encountered.
    """
    def _nstages(scheme: str) -> int:
        if scheme not in _STAGE_MAP:
            raise ValueError(f"Unknown time-integrator scheme '{scheme}'")
        return _STAGE_MAP[scheme]

    df["nstages"] = df["config:solver-time-integrator_scheme"].apply(_nstages)

def deduce_precision(df: pd.DataFrame) -> None:
    """
    Adds df['prec']  ('single' | 'double' | …) using the
    'config:backend_precision' column that comes out of
    `pyfr benchmark postprocess`.  If the column is absent we fall
    back to 'single' for every row so the rest of the script still runs.
    """
    if "config:backend_precision" in df.columns:
        df["prec"] = df["config:backend_precision"].str.lower().fillna("single")
    else:
        df["prec"] = "single"

def main():
    csv_path = parse_args()
    df = pd.read_csv(csv_path)

    df["stats:mesh_gndofs"] = pd.to_numeric(df["stats:mesh_gndofs"])
    # Sort
    df.sort_values("stats:mesh_gndofs", inplace=True)


    needed = {
        "stats:observer-onerankcomputetime_mean",
        "stats:observer-onerankcomputetime_sem",
        "stats:mesh_gndofs",
        "config:solver_order",
    }
    missing = needed - set(df.columns)
    if missing:
        raise RuntimeError(
            "CSV is missing required columns:\n  " + "\n  ".join(sorted(missing))
        )

    deduce_element_type(df)
    deduce_precision(df)
    add_stage_count(df)

    # ------------------------------------------------------------------ #
    # throughput + error propagation
    df["throughput"] = (
        df["stats:mesh_gndofs"] * df["nstages"] /
        df["stats:observer-onerankcomputetime_mean"]
        )
    df["throughput_sem"] = (
        df["stats:mesh_gndofs"]
        / df["stats:observer-onerankcomputetime_mean"] ** 2
        * df["stats:observer-onerankcomputetime_sem"]
        )

    # ------------------------------------------------------------------ #
    # ------------------------------------------------------------------ #
    #  ❱❱  REPLACED BLOCK – 2×2 layout by precision and element type ❰❰
    fig, axes = plt.subplots(2, 2, 
                             figsize=(20, 12), dpi=200, 
                             sharex=False, sharey=False, 
                             constrained_layout=True
    )
    grid_map = {
        ("single", "tet"):  (0, 0),
        ("single", "hex"):  (0, 1),
        ("double", "tet"):  (1, 0),
        ("double", "hex"):  (1, 1),
    }
    
    # ── HARD-CODED COLOUR MAP FOR p = 2…6 ────────────────────────────────
    # Matplotlib default colour cycle → blue, orange, green, red, purple
    base = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    order_colour = {2: base[0],   # blue
                    3: base[1],   # orange
                    4: base[2],   # green
                    5: base[3],   # red
                    6: base[4]}   # purple

    for prec in ["single", "double"]:
        for et in ["tet", "hex"]:
            ax = axes[grid_map[(prec, et)]]
            sub = df[(df["prec"] == prec) & (df["etype"] == et)]
            if sub.empty:
                ax.set_visible(False)
                continue

            ax.set_title(f"{et} – {prec}")
            ax.set_xscale("log")
            ax.set_yscale("log")
            ax.grid(True, which="both", linestyle="--", linewidth=0.5)
            orders = sorted(sub["config:solver_order"].unique())
            # ── inside the big for-loop over prec / et ────────────────────────────
            for p in orders:
                
                s = (
                    sub[sub["config:solver_order"] == p]
                    .sort_values("stats:mesh_gndofs")          #  ← add this line back
                )

                x_last, y_last = s.iloc[-1][["stats:mesh_gndofs", "throughput"]]
                label = rf"p = {p}  (largest mesh {y_last/1e9:.2f} GDoF/s)"

                ax.errorbar(
                    s["stats:mesh_gndofs"], s["throughput"], yerr=s["throughput_sem"],
                    fmt="o", markersize=2, color=order_colour[p], linestyle="-",
                    linewidth=1, capsize=3, label= label,
                )
                        
                # ── NEW: annotate right-most point ────────────────────────────────────
                # last row in the sorted DataFrame  → right-most on log-x axis
                label   = f"{y_last/1e9:.2f} GDoF/s"

                # small offset so text isn’t on top of the marker
                ax.annotate(
                    label,
                    xy=(x_last, y_last),
                    xytext=(5, 0),                    # 5 px to the right
                    textcoords="offset points",
                    va="center",
                    fontsize="x-small",
                )
        
            ax.set_xlim(left=6e5, right=2e9)
            ax.set_ylim(bottom=1e9, top=2e10)

            ax.set_xlabel("Global DOFs")
            ax.legend(fontsize="small")

    axes[0, 0].set_ylabel("Throughput  (DOF s$^{-1}$)")
    axes[1, 0].set_ylabel("Throughput  (DOF s$^{-1}$)")
    fig.suptitle("PyFR throughput – single precision (top) / double precision (bottom)",
            fontweight="bold")

    out_png = csv_path.with_stem(csv_path.stem).with_suffix(".png")
    fig.savefig(out_png, dpi=200)
    print(f"Saved plot → {out_png}")

if __name__ == "__main__":
    main()
