#!/usr/bin/env pvpython
"""
Clean a PyFR VTU/PVTU with CleanToGrid and write selected point arrays.

Example:
    pvpython clean_to_grid.py -i tavgs.vtu -o tavgs-ctg.vtu --arrays "Avg-P" "Std-P" --weighting average_by_number

To write CSV directly:
    pvpython clean_to_grid.py -i tavgs.vtu -o tavgs-ctg.csv --arrays "Avg-P" "Std-P" --weighting average_by_number
"""
import sys, argparse
from paraview.simple import *


def cli():
    p = argparse.ArgumentParser(description="Clean PyFR VTU/PVTU and write selected arrays")
    p.add_argument("-i", "--input", required=True, help="input .vtu/.pvtu")
    p.add_argument("-o", "--output", required=True, help="output file (.vtu/.pvtu/.pvd/.csv)")
    p.add_argument("--arrays", nargs="+", default=["Pressure", "Velocity"],
                   help="point-data arrays to save")
    p.add_argument("--weighting", default="average_by_number",
                   choices=["none", "average_by_number", "average_by_area"],
                   help="point-data weighting strategy (portable alias)")
    p.add_argument("--point-merge", action="store_true",
                   help="Enable point merging explicitly (recommended)")
    return p.parse_args()


def _norm(s: str) -> str:
    return s.lower().replace(" ", "").replace("_", "").replace("-", "")


def _get_enum_strings(prop):
    """
    Return available enum strings for a StringListProperty across ParaView builds.
    """
    # Modern ParaView: StringListProperty.GetAvailable() / .Available
    if hasattr(prop, "GetAvailable"):
        try:
            return list(prop.GetAvailable())
        except Exception:
            pass

    if hasattr(prop, "Available"):
        try:
            return list(prop.Available)
        except Exception:
            pass

    # Fallback: no availability info found
    return []


def translate_weighting(requested_alias: str, prop):
    """
    Map our portable aliases -> actual ParaView enum string.
    """
    avail = _get_enum_strings(prop)
    if not avail:
        # Last resort: try setting using known strings; if it fails ParaView will error clearly.
        avail = ["Take First Point", "Average by Number", "Average by Spatial Density"]

    # Build normalized lookup from availability list
    lut = {_norm(s): s for s in avail}

    # Alias mapping
    alias = _norm(requested_alias)
    candidates = []
    if alias in ("none",):
        # In CleanToGrid docs this corresponds to "Take First Point" (not truly "None")
        candidates = ["takefirstpoint", "takefirst", "firstpoint", "first"]
    elif alias in ("averagebynumber",):
        candidates = ["averagebynumber"]
    elif alias in ("averagebyarea",):
        # 5.13 wording is "Average by Spatial Density"
        candidates = ["averagebyspatialdensity", "averagebyspatial", "spatialdensity", "averagebyarea"]

    for c in candidates:
        if c in lut:
            chosen = lut[c]
            print(f"[weighting] requested={requested_alias} chosen='{chosen}' avail={avail}")
            return chosen

    # If no match, fall back to first available
    chosen = avail[0]
    print(f"[weighting] requested={requested_alias} NO-MATCH -> chosen='{chosen}' avail={avail}")
    return chosen


def build(infile, arrays, weighting, point_merge):
    rdr = XMLUnstructuredGridReader(FileName=[infile])

    # Keep reader lean (optional)
    if hasattr(rdr, "CellArrayStatus"):
        rdr.CellArrayStatus = []
    if hasattr(rdr, "PointArrayStatus") and arrays:
        # Note: this selects arrays to load; SaveData will still choose which to write.
        rdr.PointArrayStatus = arrays

    ctg = CleantoGrid(Input=rdr)

    if point_merge and hasattr(ctg, "PointMerging"):
        ctg.PointMerging = 1

    # Map requested alias to this ParaView build’s enum string
    prop = ctg.GetProperty("PointDataWeightingStrategy")
    ctg.PointDataWeightingStrategy = translate_weighting(weighting, prop)

    # Make sure pipeline updates with chosen settings before writing
    ctg.UpdatePipeline()
    return ctg


def main():
    args = cli()
    ds = build(args.input, args.arrays, args.weighting, args.point_merge)

    # If output is CSV, force point association and include coordinates if supported
    kw = {}
    if args.output.lower().endswith((".csv", ".tsv")):
        kw["FieldAssociation"] = "Point Data"  # CSVWriter supports this :contentReference[oaicite:2]{index=2}
        # Some builds use DataSetCSVWriter under the hood; AddMetaData adds coords when available
        kw["AddMetaData"] = 1

    SaveData(args.output, proxy=ds,
             ChooseArraysToWrite=1,
             PointDataArrays=args.arrays,
             **kw)

    print(f"[write] output={args.output} arrays={args.arrays}")


if __name__ == "__main__":
    main()
