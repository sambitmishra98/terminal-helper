#!/usr/bin/env python3
"""Generate a CSV describing Taylor–Green vortex (TGV) benchmark meshes.

The heuristic is:
    - Choose a *baseline* problem size in total degrees-of-freedom (DoF).
    - Multiply this baseline by one or more *multipliers* (e.g. 0.25, 1, 4)
      to span the rising, critical and bandwidth‑saturated regimes.
    - For each mesh element type (tet/hex/...), polynomial order, precision,
      and partition count, emit a row with a consistent basename pattern.

The script is intentionally simple, keeping the core row‑generation logic
isolated in :func:`build_rows` so that future parameters (e.g. precision,
partition counts, node allocations) can be plugged in with minimum
modification.

Example
-------
>>> python generate_tgv_bench_csv.py                # creates tgv_bench.csv
>>> python generate_tgv_bench_csv.py -o my.csv \
        --baseline-dof 9000000 --multipliers 0.25,1,4 --orders 2,4,6

The generated CSV can be fed directly to downstream automation that builds
meshes, partitions them, and submits the PyFR sbatch jobs.

"""

from __future__ import annotations

import argparse
import csv
import itertools
import math
from pathlib import Path
from typing import Iterable

HEADER = [
    # Section,Key in workflow
    "mesh:etype",                       # Element type (tet, hex, …)
    "mesh:order",                       # Polynomial order of the mesh
    "config:backend_precision",         # single | double
    "config:solver_order",              # Duplicate of order – kept for clarity
    "mesh:dof",                         # Total degrees‑of‑freedom
    "mesh:partitions",                  # Number of partitions for PyFR
    "config:soln-plugin-writer_basename",
    "script:--nodes"                    # Convenience column for sbatch helper
]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Generate a CSV enumerating PyFR TGV benchmark cases."
    )
    p.add_argument(
        "-o", "--output", help="Output CSV path (default: %(default)s)"
    )
    p.add_argument(
        "--elem-types", help="Comma‑separated list of element types (default: %(default)s)"
    )
    p.add_argument(
        "--orders", help="Comma‑separated polynomial orders to test (default: %(default)s)"
    )
    p.add_argument(
        "--baseline-dof", type=int, help="Critical (saturation) mesh size in DoF (default: %(default)s)"
    )
    p.add_argument(
        "--precision", choices=("single", "double"),
        help="Backend precision (default: %(default)s)"
    )
    p.add_argument(
        "--partitions", default="1",
        help="Partitions to emit (single value or comma‑list; default: %(default)s)"
    )
    p.add_argument(
        "--nodes-per-partition", type=int, default=1,
        help="Default sbatch --nodes to associate with each partition count"
    )
    return p.parse_args()


def build_rows(
    etypes: Iterable[str],
    orders: Iterable[int],
    baseline_dof: int,
    multipliers: Iterable[float],
    precision: str,
    partitions: Iterable[int],
    nodes_per_partition: int,
) -> list[list[str]]:
    """Return list of rows for the CSV (excluding header)."""

    rows: list[list[str]] = []
    for etype, order, mult, part in itertools.product(
        etypes, orders, multipliers, partitions
    ):
        dof = int(round(baseline_dof * mult))
        basename = f"{etype}P{precision}p{order}d{dof}"
        rows.append([
            etype,
            str(order),
            precision,
            str(order),          # solver order mirrors mesh order
            str(dof),
            str(part),
            basename,
            str(nodes_per_partition * part),
        ])
    return rows


def main() -> None:
    ns = parse_args()

    etypes = [e.strip() for e in ns.elem_types.split(',') if e.strip()]
    orders = [int(o) for o in ns.orders.split(',') if o.strip()]
    multipliers = [float(m) for m in ns.multipliers.split(',') if m.strip()]
    partitions = [int(p) for p in ns.partitions.split(',') if p.strip()]

    rows = build_rows(
        etypes=etypes,
        orders=orders,
        baseline_dof=ns.baseline_dof,
        multipliers=multipliers,
        precision=ns.precision,
        partitions=partitions,
        nodes_per_partition=ns.nodes_per_partition,
    )

    out_path = Path(ns.output).expanduser().resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open('w', newline='') as fp:
        w = csv.writer(fp)
        w.writerow(HEADER)
        w.writerows(rows)

    print(f"[✓] Wrote {len(rows)} rows to {out_path}")
    print("     First 5 rows:")
    for r in rows[:5]:
        print("     ", r)


if __name__ == "__main__":  # pragma: no cover
    main()