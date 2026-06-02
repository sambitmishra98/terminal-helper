#!/usr/bin/env python3
"""Fast summary for ASCII Gmsh 2.2 meshes used before PyFR import."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

GMSH_TYPES = {
    1: ("line2", 1), 2: ("tri3", 2), 3: ("quad4", 2),
    4: ("tet4", 3), 5: ("hex8", 3), 6: ("pri6", 3), 7: ("pyr5", 3),
    8: ("line3", 1), 9: ("tri6", 2), 10: ("quad9", 2),
    11: ("tet10", 3), 12: ("hex27", 3), 13: ("pri18", 3),
    14: ("pyr14", 3), 15: ("point", 0), 16: ("quad8", 2),
    17: ("hex20", 3), 18: ("pri15", 3), 19: ("pyr13", 3),
}


def seek(lines, token, i=0):
    while i < len(lines) and lines[i].strip() != token:
        i += 1
    return i


def read_physical_names(lines):
    i = seek(lines, "$PhysicalNames")
    if i == len(lines):
        return {}
    n = int(lines[i + 1])
    names = {}
    for line in lines[i + 2:i + 2 + n]:
        parts = line.split(maxsplit=2)
        dim, tag = int(parts[0]), int(parts[1])
        name = parts[2].strip().strip('"')
        names[tag] = {"dim": dim, "name": name}
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mesh", type=Path)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    lines = args.mesh.read_text(errors="replace").splitlines()
    phys = read_physical_names(lines)

    i = seek(lines, "$Nodes")
    if i == len(lines):
        raise SystemExit("no $Nodes section found")
    nnodes = int(lines[i + 1])
    mins = [float("inf")] * 3
    maxs = [float("-inf")] * 3
    for line in lines[i + 2:i + 2 + nnodes]:
        p = line.split()
        xyz = list(map(float, p[1:4]))
        mins = [min(a, b) for a, b in zip(mins, xyz)]
        maxs = [max(a, b) for a, b in zip(maxs, xyz)]

    j = seek(lines, "$Elements")
    if j == len(lines):
        raise SystemExit("no $Elements section found")
    neles = int(lines[j + 1])
    by_type = Counter()
    by_dim = Counter()
    by_phys = Counter()
    phys_by_type = defaultdict(Counter)

    for line in lines[j + 2:j + 2 + neles]:
        p = line.split()
        etype = int(p[1])
        ntags = int(p[2])
        tags = list(map(int, p[3:3 + ntags]))
        phys_tag = tags[0] if tags else None
        name, dim = GMSH_TYPES.get(etype, (f"gmsh_{etype}", -1))
        by_type[name] += 1
        by_dim[str(dim)] += 1
        if phys_tag is not None:
            pname = phys.get(phys_tag, {}).get("name", str(phys_tag))
            by_phys[pname] += 1
            phys_by_type[pname][name] += 1

    out = {
        "file": str(args.mesh),
        "nodes": nnodes,
        "bbox": {"min": mins, "max": maxs},
        "elements_total": neles,
        "elements_by_type": dict(sorted(by_type.items())),
        "elements_by_dimension": dict(sorted(by_dim.items())),
        "physical_names": phys,
        "elements_by_physical": dict(sorted(by_phys.items())),
        "elements_by_physical_and_type": {
            k: dict(v) for k, v in sorted(phys_by_type.items())
        },
    }

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"file: {args.mesh}")
        print(f"nodes: {nnodes}")
        print(f"bbox: x=[{mins[0]:.9g}, {maxs[0]:.9g}], "
              f"y=[{mins[1]:.9g}, {maxs[1]:.9g}], "
              f"z=[{mins[2]:.9g}, {maxs[2]:.9g}]")
        print(f"elements_total: {neles}")
        print("elements_by_type:")
        for k, v in sorted(by_type.items()):
            print(f"  {k}: {v}")
        print("elements_by_physical:")
        for k, v in sorted(by_phys.items()):
            print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
