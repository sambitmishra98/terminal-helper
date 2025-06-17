#!/usr/bin/env python3
"""
generate_bench_csv.py
---------------------
Dynamic CSV generator for PyFR TGV benchmarking.

Example
~~~~~~~
python generate_bench_csv.py \
    --mesh:etype              hex,tet \
    --mesh:order              2,3,4,5,6 \
    --mesh:dof                2500000,10000000,40000000 \
    --config:backend_precision double \
    --mesh:partitions         1 \
    --script:--nodes          1 \
    -o tgv_bench.csv
"""

from __future__ import annotations
import argparse, csv, itertools, sys, warnings
from collections import defaultdict
from pathlib     import Path

# ------------------------------------------------------------------ utilities
def parse_dynamic_args(argv):
    """Return (known_args, header→list[str]), leaving only -o/--output as fixed."""
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("-o", "--output", default="tgv_bench.csv",
                    help="Destination CSV (default: %(default)s)")
    known, unknown = ap.parse_known_args(argv)

    headers = defaultdict(list)                 # {full_header: [values]}
    i = 0
    while i < len(unknown):
        tok = unknown[i]
        if not tok.startswith("--") or ":" not in tok:
            raise SystemExit(f"Malformed option '{tok}'. "
                             "Custom flags must contain a colon, e.g. --mesh:order 2,4")
        if "=" in tok:
            key, val = tok[2:].split("=", 1)
            i += 1
        else:
            key, val = tok[2:], unknown[i + 1]
            i += 2
        headers[key].extend(v.strip() for v in val.split(",") if v.strip())
    return known, dict(headers)


def ensure_order_pair(headers: dict[str, list[str]]) -> tuple[list[str], bool]:
    """
    Ensure mesh:order and config:solver_order both exist and are equal.
    Returns (header_order, auto_solver_bool).
    """
    mo = "mesh:order"
    so = "config:solver_order"
    header_order = list(headers.keys())         # preserve CLI order
    auto_solver = False

    if mo in headers and so not in headers:
        headers[so] = headers[mo]               # create alias list
        auto_solver = True
    elif so in headers and mo not in headers:
        headers[mo] = headers[so]
        header_order.insert(header_order.index(so), mo)   # keep logical order
        auto_solver = True
    elif mo in headers and so in headers and headers[mo] != headers[so]:
        warnings.warn("mesh:order and config:solver_order differ; using mesh:order.")
        headers[so] = headers[mo]               # force equality

    # If auto_solver is True we *exclude* solver_order from the product grid
    return header_order, auto_solver


def build_abbrev_map(header_names):
    """
    Create {full_header → abbrev} where abbrev = namespace initial (m/c/s) +
    '_' + shortest unique prefix of field.
    """
    per_ns = defaultdict(set)
    m = {}
    for full in header_names:
        ns, field = full.split(":", 1)
        ns_initial = {"mesh": "m", "config": "c", "script": "s"}.get(ns, "x")
        for n in range(1, len(field) + 1):
            candidate = f"{ns_initial}_{field[:n]}"
            if candidate not in per_ns[ns]:
                per_ns[ns].add(candidate)
                m[full] = candidate
                break
    return m


def make_basename(row_vals, abbrev_map, skip_prefix=("script:",)):
    parts = []
    for full_key, short in abbrev_map.items():
        if full_key.startswith(skip_prefix):
            continue
        parts.append(f"{short}-{row_vals[full_key]}")
    return "__".join(parts)

# --------------------------------------------------------------------- main
def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]

    known, headers = parse_dynamic_args(argv)
    if not headers:
        raise SystemExit("No header flags provided.")

    header_order, auto_solver = ensure_order_pair(headers)

    # Build list of headers that enter the Cartesian product
    grid_headers = [h for h in header_order if not (auto_solver and h == "config:solver_order")]

    # Abbreviation map (uses *all* headers, including solver_order)
    abbrev_map = build_abbrev_map(header_order if "config:solver_order" in header_order
                                  else header_order + ["config:solver_order"])

    # Cartesian product of values
    value_lists = [headers[h] for h in grid_headers]
    rows = []
    for combo in itertools.product(*value_lists):
        row_dict = dict(zip(grid_headers, combo))

        # Inject solver_order if it was auto
        if auto_solver:
            row_dict["config:solver_order"] = row_dict["mesh:order"]

        # Build row in full header order
        full_row = [row_dict[h] for h in header_order] + \
                   [row_dict["config:solver_order"]] + \
                   [make_basename(row_dict, abbrev_map)]

        rows.append(full_row)

    header_out = header_order + ["config:solver_order", "config:soln-plugin-writer_basename"]

    # Write CSV
    out_path = Path(known.output).expanduser().resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as fh:
        csv.writer(fh).writerows([header_out, *rows])

    print(f"[✓] Wrote {len(rows)} rows → {out_path}")
    if rows:
        print("     Sample row:", dict(zip(header_out, rows[0])))

# ---------------------------------------------------------------------------
if __name__ == "__main__":
    main()
