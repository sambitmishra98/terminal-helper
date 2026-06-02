#!/usr/bin/env python3
"""Summarise a PyFR .pyfrm and check colour labels relevant to block-Jacobi."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

import numpy as np


def _decode(x):
    if isinstance(x, bytes):
        return x.decode(errors="replace").rstrip("\x00")
    return x


def _shape_order(etype, nupts):
    # PyFR standard nodal counts by element type.
    for p in range(1, 20):
        if etype == "hex" and (p + 1) ** 3 == nupts:
            return p
        if etype == "tet" and (p + 1) * (p + 2) * (p + 3) // 6 == nupts:
            return p
        if etype == "pri" and (p + 1) ** 2 * (p + 2) // 2 == nupts:
            return p
        if etype == "pyr" and (p + 1) * (p + 2) * (2 * p + 3) // 6 == nupts:
            return p
        if etype == "quad" and (p + 1) ** 2 == nupts:
            return p
        if etype == "tri" and (p + 1) * (p + 2) // 2 == nupts:
            return p
    return None


def _h5dump_datasets(path):
    h5dump = shutil.which("h5dump")
    if not h5dump:
        return []
    p = subprocess.run([h5dump, "-n", str(path)], text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       check=False)
    if p.returncode != 0:
        return []
    out = []
    for line in p.stdout.splitlines():
        m = re.search(r"dataset\s+(/\S+)", line)
        if m:
            out.append(m.group(1))
    return out


def _h5dump_shape(path, dset):
    h5dump = shutil.which("h5dump")
    if not h5dump:
        return None
    p = subprocess.run([h5dump, "-H", "-d", dset, str(path)], text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       check=False)
    if p.returncode != 0:
        return None
    m = re.search(r"DATASPACE\s+SIMPLE\s+\{\s+\(\s*([^)]*?)\s*\)", p.stdout)
    if not m:
        return None
    vals = [v.strip() for v in m.group(1).split(",") if v.strip()]
    return [int(v) for v in vals if v.isdigit()]


def h5py_summary(path, args):
    import h5py

    with h5py.File(path, "r") as f:
        out = {
            "file": str(path),
            "version": int(f["version"][()]) if "version" in f else None,
            "creator": _decode(f["creator"][()]) if "creator" in f else None,
            "mesh_uuid": _decode(f["mesh-uuid"][()]) if "mesh-uuid" in f else None,
            "codec": [_decode(v) for v in f["codec"][()]] if "codec" in f else [],
            "nodes": None,
            "bbox": None,
            "element_types": {},
            "partitionings": {},
            "warnings": [],
        }

        try:
            nodes = f["nodes"]
            out["nodes"] = int(nodes.shape[0])
            loc = nodes["location"]
            out["bbox"] = {
                "min": np.min(loc, axis=0).astype(float).tolist(),
                "max": np.max(loc, axis=0).astype(float).tolist(),
            }
        except Exception as e:
            out["warnings"].append(f"could not read nodes: {e}")

        colours_by_type = {}
        for etype in sorted(f["eles"]):
            try:
                ds = f[f"eles/{etype}"]
                neles = int(ds.shape[0])
                info = {"neles": neles}
                if "nodes" in ds.dtype.fields:
                    nnodes = int(ds.dtype["nodes"].shape[0])
                    info["nodes_per_element"] = nnodes
                    info["mesh_order_guess"] = _shape_order(etype, nnodes)
                if "curved" in ds.dtype.fields:
                    curved = ds["curved"]
                    info["curved"] = int(np.count_nonzero(curved))
                if "colour" in ds.dtype.fields:
                    colours = ds["colour"]
                    colours_by_type[etype] = colours
                    labels, counts = np.unique(colours, return_counts=True)
                    labels_i = labels.astype(int).tolist()
                    info["colour_labels"] = labels_i
                    info["colour_counts"] = dict(zip(map(str, labels_i),
                                                       map(int, counts)))
                    expect = list(range(len(labels_i)))
                    if labels_i != expect:
                        out["warnings"].append(
                            f"global colours for {etype} are {labels_i}, not {expect}"
                        )
                out["element_types"][etype] = info
            except Exception as e:
                out["element_types"][etype] = {"error": str(e)}

        if "partitionings" in f:
            etypes = sorted(f["eles"])
            for pname in sorted(f["partitionings"]):
                ds = f[f"partitionings/{pname}/eles"]
                regions = np.array(ds.attrs["regions"])
                pinfo = {"nparts": int(regions.shape[0]), "local_colour_warnings": []}
                counts = []
                for r, row in enumerate(regions):
                    rc = {}
                    for i, etype in enumerate(etypes):
                        start, end = int(row[i]), int(row[i + 1])
                        idxs = ds[start:end]
                        rc[etype] = int(len(idxs))
                        if etype in colours_by_type and len(idxs):
                            labs = np.unique(colours_by_type[etype][idxs]).astype(int).tolist()
                            expect = list(range(len(labs)))
                            if labs != expect:
                                pinfo["local_colour_warnings"].append({
                                    "rank": r, "etype": etype,
                                    "labels": labs, "expected_if_slot_indexed": expect,
                                })
                    counts.append(rc)
                pinfo["local_element_counts"] = counts
                out["partitionings"][pname] = pinfo

        if args.order is not None:
            nvars = args.nvars
            dofs = {}
            total = 0
            for etype, info in out["element_types"].items():
                neles = info.get("neles")
                if not neles:
                    continue
                if etype == "hex":
                    nupts = (args.order + 1) ** 3
                elif etype == "tet":
                    p = args.order
                    nupts = (p + 1) * (p + 2) * (p + 3) // 6
                elif etype == "pri":
                    p = args.order
                    nupts = (p + 1) ** 2 * (p + 2) // 2
                elif etype == "pyr":
                    p = args.order
                    nupts = (p + 1) * (p + 2) * (2 * p + 3) // 6
                else:
                    continue
                solpts = int(neles * nupts)
                dofs[etype] = {"solution_points": solpts,
                               "conservative_dofs": solpts * nvars}
                total += solpts * nvars
            out["solver_order_assumption"] = args.order
            out["nvars_assumption"] = nvars
            out["dofs"] = dofs
            out["total_conservative_dofs"] = total

        return out


def fallback_summary(path):
    dsets = _h5dump_datasets(path)
    out = {"file": str(path), "datasets": dsets, "element_types": {},
           "warnings": ["h5py summary failed, using h5dump header fallback"]}
    for dset in dsets:
        m = re.match(r"/eles/(\w+)$", dset)
        if m:
            shape = _h5dump_shape(path, dset)
            out["element_types"][m.group(1)] = {"shape_from_h5dump": shape}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mesh", type=Path)
    ap.add_argument("--order", type=int, help="solver polynomial order for DOF estimate")
    ap.add_argument("--nvars", type=int, default=5, help="conserved variables, default 5")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        out = h5py_summary(args.mesh, args)
    except Exception as e:
        out = fallback_summary(args.mesh)
        out["warnings"].append(str(e))

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"file: {out['file']}")
        if out.get("creator"):
            print(f"creator: {out['creator']}")
        if out.get("mesh_uuid"):
            print(f"mesh_uuid: {out['mesh_uuid']}")
        if out.get("nodes"):
            print(f"nodes: {out['nodes']}")
        if out.get("bbox"):
            b = out["bbox"]
            print(f"bbox: min={b['min']} max={b['max']}")
        print("element_types:")
        for et, info in out.get("element_types", {}).items():
            print(f"  {et}: {info}")
        if out.get("total_conservative_dofs") is not None:
            print(f"total_conservative_dofs: {out['total_conservative_dofs']}")
        if out.get("partitionings"):
            print("partitionings:")
            for pn, pi in out["partitionings"].items():
                nw = len(pi.get("local_colour_warnings", []))
                print(f"  {pn}: nparts={pi['nparts']} local_colour_warnings={nw}")
        if out.get("warnings"):
            print("warnings:")
            for w in out["warnings"][:20]:
                print(f"  - {w}")


if __name__ == "__main__":
    main()
