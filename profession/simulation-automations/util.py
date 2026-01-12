# ───────────────────────── util.py ─────────────────────────
"""Tiny helpers – imported by the main script."""

from __future__ import annotations
from pathlib import Path
import glob
import numpy as np
import pandas as pd

# ---------- geometry helpers -------------------------------------------------
def infer_nx_ny_nz(arr_len: int, spacings: str) -> tuple[int, int, int]:
    """
    Return *(nx, ny, nz)* inferred from the original `[nx,ny,nz]` string.

    Raises if the product does not match *arr_len* – that is, when the user
    gave inconsistent spacing information.
    """
    nx, ny, nz = (int(eval(s.strip())) for s in spacings.strip('[]').split(','))
    if arr_len != nx * ny * nz:
        raise ValueError("array length does not match nx*ny*nz – check spacings")
    return nx, ny, nz


def spanwise_mean(arr: np.ndarray, nx: int, ny: int, nz: int) -> np.ndarray:
    """
    Collapse z (axis = -1).  The returned 1-D profile is over *x* if *ny=1*,
    otherwise over *y*.  Either *(nx==1 xor ny==1)* must hold.
    """
    if (nx == 1) ^ (ny == 1):
        new_shape = (ny, nz) if nx == 1 else (nx, nz)
        return arr.reshape(new_shape).mean(axis=1)
    raise ValueError("Cannot collapse z when both nx and ny are > 1")


# ---------- references helper -----------------------------------------------
def load_reference_csvs(patterns: str) -> list[pd.DataFrame]:
    """
    Expand wild-cards, read CSVs, attach `stem` as label, and return a list.
    """
    refs: list[pd.DataFrame] = []
    for pat in patterns.split(','):
        for p in map(Path, glob.glob(pat.strip()) or [pat.strip()]):
            if p.exists():
                df = pd.read_csv(p, comment='#', skip_blank_lines=True)
                df.attrs['label'] = p.stem
                refs.append(df)
    return refs
