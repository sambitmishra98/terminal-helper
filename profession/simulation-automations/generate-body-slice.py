
#!/usr/bin/env python3
"""generate_sample_grid.py

Generate Cartesian sampling points outside a closed STL surface, suitable
for PyFR's 'sample' CLI.  Requires `numpy`, `trimesh`, and `rtree`.
Install:  pip install trimesh rtree
"""
import argparse, sys  
from pathlib import Path
import numpy as np
import trimesh, rtree

def parse():
    p = argparse.ArgumentParser()
    p.add_argument("stl", help="STL file of submarine surface")
    p.add_argument("--xmin", type=float, required=True)
    p.add_argument("--xmax", type=float, required=True)
    p.add_argument("--ymin", type=float, required=True)
    p.add_argument("--ymax", type=float, required=True)
    p.add_argument("--zmin", type=float, required=True)
    p.add_argument("--zmax", type=float, required=True)
    p.add_argument("--dx", type=float, required=True)
    p.add_argument("--dy", type=float, required=True)
    p.add_argument("--dz", type=float, required=True)
    p.add_argument("--out", default=None, help="CSV file name (auto-generated if omitted)")
    p.add_argument("--precision", type=int, default=6, help="Decimal places to write (no scientific notation)")
    p.add_argument("--plot", action="store_true")
    return p.parse_args()

def main():
    a = parse()
    mesh = trimesh.load(a.stl)

    # ------------------------------------------------------------------
    # 1.  Build a unique base-name if the user didn’t supply --out
    # ------------------------------------------------------------------
    if a.out is None:
        def tag(v):          # e.g. -0.05  ->  m0p05
            s = f"{v:.{a.precision}f}".rstrip('0').rstrip('.')
            s = s.replace('-', 'm').replace('.', 'p')
            return s or "0"

        base = Path(a.stl).stem
        bbox = f"x{tag(a.xmin)}-{tag(a.xmax)}_" \
               f"y{tag(a.ymin)}-{tag(a.ymax)}_" \
               f"z{tag(a.zmin)}-{tag(a.zmax)}_" \
               f"dx{tag(a.dx)}_{tag(a.dy)}_{tag(a.dz)}"
        a.out = f"{base}_{bbox}.csv"
    png_out = Path(a.out).with_suffix('.png')   # same stem for preview



    xs = np.arange(a.xmin, a.xmax + a.dx/2, a.dx)
    ys = np.arange(a.ymin, a.ymax + a.dy/2, a.dy)
    zs = np.arange(a.zmin, a.zmax + a.dz/2, a.dz)
    X,Y,Z = np.meshgrid(xs, ys, zs, indexing='xy')
    pts = np.column_stack([X.ravel(), Y.ravel(), Z.ravel()])
    outside = ~mesh.contains(pts)
    pts_out = pts[outside]

    # ------------------------------------------------------------------
    # 2.  Save without header, fixed-point format, user-chosen precision
    # ------------------------------------------------------------------
    fmt = f"%.{a.precision}f"
    np.savetxt(a.out, pts_out, delimiter=',', fmt=fmt)

    print(f"Saved {len(pts_out)} points to {a.out}")
    if a.plot:
        import matplotlib.pyplot as plt; from mpl_toolkits.mplot3d import Axes3D  # noqa: F401
        fig = plt.figure(figsize=(6,6))
        ax = fig.add_subplot(111, projection='3d')
        idx = slice(None, None, max(len(pts_out)//5000,1))
        ax.scatter(pts_out[idx,0], pts_out[idx,1], pts_out[idx,2], s=1)
        plt.tight_layout()
        fig.savefig(png_out, dpi=300)
        plt.show()
        
if __name__ == "__main__":
    main()
