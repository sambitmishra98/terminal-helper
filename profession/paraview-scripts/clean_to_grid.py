#!/usr/bin/env pvpython
"""
Clean a PyFR VTU/PVTU with CleanToGrid and write selected point arrays.

ParaView-5.13.x renamed the weighting strings, so we detect them.

Example:
    pvpython clean_to_grid.py -i pseudores-201.vtu \
                              -o pseudores-201-ctg.pvd \
                              --arrays Pressure Velocity \
                              --weighting average_by_number
"""
import sys, argparse
from paraview.simple import *

# ------------------------------------------------------------------
def cli():
    p = argparse.ArgumentParser(
        description="Clean PyFR VTU/PVTU and write selected arrays")
    p.add_argument("-i", "--input", required=True, help="input .vtu/.pvtu")
    p.add_argument("-o", "--output", required=True, help="output file")
    p.add_argument("--arrays", nargs="+", default=["Pressure", "Velocity"],
                   help="point-data arrays to save")
    p.add_argument("--weighting", default="average_by_number",
                   choices=["none", "average_by_number", "average_by_area"],
                   help="point-data weighting strategy (ParaView name)")
    return p.parse_args()

# ------------------------------------------------------------------
def translate_weighting(requested, prop):
    """Return a valid enum string for the current ParaView build."""
    avail = prop.Domain[0].GetStrings()           # e.g. ['None','AverageByNumber']
    # normalise for case/spacing
    norm = {s.lower().replace(" ", ""): s for s in avail}
    return norm.get(requested.lower(), avail[0])  # fallback to first enum

# ------------------------------------------------------------------
def build(infile, weighting):
    rdr = XMLUnstructuredGridReader(FileName=[infile])
    rdr.CellArrayStatus = []

    ctg = CleantoGrid(Input=rdr)
    #ctg.PointMerging = True

    # map requested weighting to whatever this ParaView build calls it
    prop = ctg.GetProperty("PointDataWeightingStrategy")
    ctg.PointDataWeightingStrategy = translate_weighting(weighting, prop)
    return ctg

# ------------------------------------------------------------------
def main():
    args = cli()
    ds = build(args.input, args.weighting)
    SaveData(args.output, proxy=ds, ChooseArraysToWrite=1,
             PointDataArrays=args.arrays)

if __name__ == "__main__":
    main()