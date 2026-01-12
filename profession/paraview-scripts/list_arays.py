#!/usr/bin/env pvpython
import os, sys
from pathlib import Path
from paraview.simple import *

def make_reader(infile):
    p = Path(infile)
    if p.suffix.lower() == ".pvtu":
        return XMLPartitionedUnstructuredGridReader(FileName=[infile])
    elif p.suffix.lower() == ".vtu":
        return XMLUnstructuredGridReader(FileName=[infile])
    raise SystemExit("Expected .vtu or .pvtu")

def _rank0():
    for k in ("PMI_RANK", "OMPI_COMM_WORLD_RANK", "SLURM_PROCID"):
        if k in os.environ:
            return int(os.environ[k]) == 0
    return True

def _dump(info, title):
    print(title)
    for i in range(info.GetNumberOfArrays()):
        a = info.GetArray(i)
        name = a.GetName()
        ncomp = a.GetNumberOfComponents()
        print(f"  - {name}  (ncomp={ncomp})")

def main():
    infile = sys.argv[1]
    rdr = make_reader(infile)
    rdr.UpdatePipeline()

    if _rank0():
        _dump(rdr.GetPointDataInformation(), "POINT DATA arrays:")
        _dump(rdr.GetCellDataInformation(),  "CELL  DATA arrays:")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: pvpython pv_list_arrays.py <in.vtu|in.pvtu>")
    main()
