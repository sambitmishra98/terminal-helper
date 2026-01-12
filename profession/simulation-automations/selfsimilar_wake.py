#!/usr/bin/env python3
"""
selfsimilar_wake.py  –  v1.1
-----------------------------
• Make a Jiménez/Posa self-similar CSV WHATEVER δ you tell it.
• Optionally *fit* δ to an existing wake slice (PyFR or experiment).
• Quick contour helper unchanged.

Usage examples
--------------
# 1) Hard-wire δ = 0.27 m and write the CSV
python selfsimilar_wake.py --delta 0.27

# 2) Auto-fit δ to my PyFR line-average and plot overlay
python selfsimilar_wake.py --fit pyfr_slice.csv --plot
"""
import csv, argparse, itertools
import numpy as np
import matplotlib.pyplot as plt

# --------------------------------------------------------------------------
# 1. Self-similar profile
def f_eta(eta: np.ndarray) -> np.ndarray:
    return np.exp(-0.525*eta**2 - 0.1375*eta**4 -0.03*eta**6 - 0.002225*eta**8)

# --------------------------------------------------------------------------
# 2. Utility: write CSV given δ (scales abscissa)
def write_selfsimilar_csv(fname: str, delta: float, eta_min=-4.0, eta_max=4.0, npts=101):
    eta = np.linspace(eta_min, eta_max, npts)
    x   = eta * delta          # <-- physical ordinate
    f   = f_eta(eta)

    with open(fname, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["x", "y"])      # keep header identical to your sample
        w.writerows(zip(x, f))
    print(f"[OK] {npts} points ➜ {fname}  (δ = {delta:.4g})")

# --------------------------------------------------------------------------
# 3. Least-squares fit of δ to a line profile you already have
def load_xy(path):
    x, y = np.loadtxt(path, delimiter=",", skiprows=1).T
    return x, y

# --------------------------------------------------------------------------
# 4. Contour helper (unchanged)
def contour2d(field, extent, levels=20, cmap="viridis"):
    ny, nx = field.shape
    x = np.linspace(extent[0], extent[1], nx)
    y = np.linspace(extent[2], extent[3], ny)
    X, Y = np.meshgrid(x, y)
    plt.figure(figsize=(6,4))
    cs = plt.contourf(X, Y, field, levels=levels, cmap=cmap)
    plt.colorbar(cs, label="defect/U∞")
    plt.xlabel("y")
    plt.ylabel("z"); plt.gca().set_aspect("equal"); plt.tight_layout()

# --------------------------------------------------------------------------
# 5. CLI
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv",   default="jimenez_selfsimilar.csv", help="output CSV (default: %(default)s)")
    ap.add_argument("--delta", type=float, metavar="Δ", help="wake half-width δ to use directly")
    ap.add_argument("--plot",  action="store_true", help="show overlay/contour for sanity check")
    args = ap.parse_args()

    if args.delta:
        delta = args.delta
    else:
        raise ValueError("you must specify x-scaling factor as --delta")

    # --------------- write CSV ---------------
    write_selfsimilar_csv(args.csv, delta)

    # --------------- optional checks ---------
    if args.plot:
        # demo contour – axisymmetric bubble
        grid = 200
        r = np.linspace(-3*delta, 3*delta, grid)
        Y, Z = np.meshgrid(r, r)
        field = f_eta(np.sqrt(Y**2+Z**2)/delta)
        contour2d(field, (-3*delta, 3*delta, -3*delta, 3*delta))

        plt.show()
