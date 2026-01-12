#!/usr/bin/env pvbatch
import argparse
from paraview.simple import *

def _try_set(obj, name, value):
    if hasattr(obj, name):
        try:
            setattr(obj, name, value)
            print(f"[set] {obj.SMProxy.GetXMLLabel()}.{name} = {value}")
            return True
        except Exception:
            pass
    return False

def list_point_arrays(proxy, tag="[arrays]"):
    pdi = proxy.GetPointDataInformation()
    names = []
    for i in range(pdi.GetNumberOfArrays()):
        names.append(pdi.GetArray(i).GetName())
    print(tag, "POINT:", names)
    return set(names)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--input", required=True, help="input .vtu/.pvtu")
    ap.add_argument("-o", "--output", required=True, help="output .vtu/.pvtu")
    ap.add_argument("--keep-all", action="store_true",
                    help="write all arrays (otherwise only Velocity, Vorticity, Q-criterion)")
    args = ap.parse_args()

    DisableFirstRenderCameraReset() if 'DisableFirstRenderCameraReset' in globals() else None
    # NOTE: ParaView 6 trace uses paraview.simple._DisableFirstRenderCameraReset();
    # for pvbatch headless you can ignore camera reset entirely.

    # Reader (works for .vtu and .pvtu)
    src = OpenDataFile(args.input)
    if src is None:
        raise SystemExit(f"[err] cannot open {args.input}")

    # Keep reader lean unless user asked keep-all
    if (not args.keep_all) and hasattr(src, "PointArrayStatus"):
        src.PointArrayStatus = ["Velocity", "Grad Velocity"]

    src.UpdatePipeline()
    list_point_arrays(src, tag="[in]")

    # CleanToGrid
    ctg = CleantoGrid(Input=src)

    # Always: average-by-number (your requirement; matches GUI trace)
    if hasattr(ctg, "PointDataWeightingStrategy"):
        ctg.PointDataWeightingStrategy = "Average by Number"

    # Always: enable point merging (property name differs across builds)
    if not (_try_set(ctg, "PointMerging", 1) or _try_set(ctg, "MergePoints", 1)):
        print("[ctg] point merging: no explicit toggle exposed; continuing")

    ctg.UpdatePipeline()
    pnames = list_point_arrays(ctg, tag="[ctg]")

    # Sanity: we need Grad Velocity components for Q and Vorticity
    if "Grad Velocity" not in pnames or "Velocity" not in pnames:
        raise SystemExit("[err] Need POINT arrays 'Velocity' and 'Grad Velocity' after CleanToGrid.")

    # Calculator: Q-criterion from Grad Velocity (your GUI expression)
    calcQ = Calculator(Input=ctg)
    calcQ.ResultArrayName = "Q-criterion"
    calcQ.Function = (
        '-0.5*( "Grad Velocity_XX"*"Grad Velocity_XX"'
        '      + "Grad Velocity_YY"*"Grad Velocity_YY"'
        '      + "Grad Velocity_ZZ"*"Grad Velocity_ZZ" )'
        ' -( "Grad Velocity_XY"*"Grad Velocity_YX"'
        '  + "Grad Velocity_XZ"*"Grad Velocity_ZX"'
        '  + "Grad Velocity_YZ"*"Grad Velocity_ZY" )'
    )

    calcQ.UpdatePipeline()

    # Calculator: Vorticity vector ω = ∇×u from Grad Velocity
    # ωx = dVz/dy - dVy/dz = ZY - YZ
    # ωy = dVx/dz - dVz/dx = XZ - ZX
    # ωz = dVy/dx - dVx/dy = YX - XY
    calcW = Calculator(Input=calcQ)
    calcW.ResultArrayName = "Vorticity"
    calcW.Function = (
        '( "Grad Velocity_ZY" - "Grad Velocity_YZ")*iHat + '
        '( "Grad Velocity_XZ" - "Grad Velocity_ZX")*jHat + '
        '( "Grad Velocity_YX" - "Grad Velocity_XY")*kHat'
    )

    calcW.UpdatePipeline()
    outnames = list_point_arrays(calcW, tag="[out]")

    # Write
    if args.keep_all:
        SaveData(args.output, proxy=calcW)
        print(f"[write] output={args.output} keep_all=True")
    else:
        want = ["Velocity", "Vorticity", "Q-criterion"]
        missing = [w for w in want if w not in outnames]
        if missing:
            raise SystemExit(f"[err] Missing requested arrays at output: {missing}")
        SaveData(
            args.output,
            proxy=calcW,
            ChooseArraysToWrite=1,
            PointDataArrays=want
        )
        print(f"[write] output={args.output} keep_all=False PointDataArrays={want}")

if __name__ == "__main__":
    main()
