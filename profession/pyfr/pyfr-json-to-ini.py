#!/usr/bin/env python3
"""Convert a small JSON summary into an INI-like flattened report.

This is intended for PyFR case-card metadata, not for generating a PyFR
solver input file. Keep extracted *.pyfrs.config.ini files unchanged.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def flatten(prefix: str, value: Any, out: dict[str, str]) -> None:
    """Flatten nested JSON data into dotted keys."""
    if isinstance(value, dict):
        if not value:
            out[prefix] = "{}"
        for key, subval in value.items():
            skey = str(key).replace(" ", "_")
            flatten(f"{prefix}.{skey}" if prefix else skey, subval, out)
    elif isinstance(value, list):
        if all(not isinstance(x, (dict, list)) for x in value):
            out[prefix] = ",".join(str(x) for x in value)
        else:
            for i, subval in enumerate(value):
                flatten(f"{prefix}.{i}", subval, out)
    elif value is None:
        out[prefix] = "none"
    elif isinstance(value, bool):
        out[prefix] = "true" if value else "false"
    else:
        out[prefix] = str(value)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert JSON case-card metadata into an INI-like report."
    )
    ap.add_argument("json_file", type=Path)
    ap.add_argument("--section", default="case-summary")
    args = ap.parse_args()

    data = json.loads(args.json_file.read_text())
    flat: dict[str, str] = {}
    flatten("", data, flat)

    print(f"[{args.section}]")
    for key in sorted(flat):
        safe_key = key.replace("/", "_")
        print(f"{safe_key} = {flat[key]}")


if __name__ == "__main__":
    main()
