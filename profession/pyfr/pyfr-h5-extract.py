#!/usr/bin/env python3
"""Extract ground-truth /config and /stats strings from PyFR HDF5 files.

Use this on .pyfrs files first. The saved /config is the exact input that
produced the solution file, so prefer it over a nearby .ini.
"""

from __future__ import annotations

import argparse
import ast
import json
import shutil
import subprocess
from pathlib import Path
from typing import Any


def _decode(x: Any) -> Any:
    if isinstance(x, bytes):
        return x.decode(errors="replace").rstrip("\x00")
    if hasattr(x, "tolist"):
        return _decode(x.tolist())
    if isinstance(x, list):
        return [_decode(v) for v in x]
    return x


def _h5py_read(path: Path, dset: str) -> Any:
    import h5py

    with h5py.File(path, "r") as f:
        obj = f[dset]
        return _decode(obj[()])


def _h5dump_read_scalar_string(path: Path, dset: str) -> str:
    h5dump = shutil.which("h5dump")
    if not h5dump:
        raise RuntimeError("h5py failed and h5dump was not found in PATH")

    cmd = [h5dump, "-d", dset, str(path)]
    p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, check=False)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or f"h5dump failed for {dset}")

    lines = p.stdout.splitlines()
    start = None
    for i, line in enumerate(lines):
        marker = ") : \""
        # Common h5dump format is: (0): "..."
        if ") : \"" in line or "): \"" in line:
            start = i
            break
    if start is None:
        raise RuntimeError(f"could not find scalar string payload for {dset}")

    first = lines[start]
    payload = first.split('"', 1)[1]
    body_lines = [payload]

    for line in lines[start + 1:]:
        # Final payload line ends with a quote before the dataset closing brace.
        if line.endswith('"'):
            body_lines.append(line[:-1])
            break
        body_lines.append(line)

    text = "\n".join(body_lines)

    # If h5dump escaped the payload, decode it. If not, leave it unchanged.
    try:
        return ast.literal_eval('"' + text.replace('"', '\\"') + '"')
    except Exception:
        return text.rstrip("\x00")


def read_dataset(path: Path, dset: str) -> Any:
    dset = dset if dset.startswith("/") else "/" + dset
    try:
        return _h5py_read(path, dset)
    except Exception:
        return _h5dump_read_scalar_string(path, dset)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("file", type=Path, help="PyFR .pyfrs, .pyfrm, or other HDF5 file")
    ap.add_argument("--datasets", nargs="+", default=["config", "stats"],
                    help="datasets to extract, default: config stats")
    ap.add_argument("--outdir", type=Path, default=None,
                    help="write one file per dataset into this directory")
    ap.add_argument("--json", action="store_true", help="print JSON to stdout")
    args = ap.parse_args()

    out = {}
    for dset in args.datasets:
        try:
            out[dset.strip("/")] = read_dataset(args.file, dset)
        except Exception as e:
            out[dset.strip("/")] = {"error": str(e)}

    if args.outdir:
        args.outdir.mkdir(parents=True, exist_ok=True)
        stem = args.file.name
        for key, val in out.items():
            suffix = ".ini"
            op = args.outdir / f"{stem}.{key}{suffix}"
            if isinstance(val, (dict, list)):
                op.write_text(json.dumps(val, indent=2) + "\n")
            else:
                op.write_text(str(val).rstrip() + "\n")

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        for key, val in out.items():
            print(f"===== /{key} =====")
            if isinstance(val, (dict, list)):
                print(json.dumps(val, indent=2))
            else:
                print(str(val).rstrip())


if __name__ == "__main__":
    main()
