import pandas as pd
from pathlib import Path

src_dir = Path("/mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/simulation-automations/references/sd7003/wall/C_p")   # wherever your current refs are
u_dir   = Path("/mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/simulation-automations/references/sd7003/wall/C_p/mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/simulation-automations/references/sd7003/wall/C_p/upper")
l_dir   = Path("/mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/simulation-automations/references/sd7003/wall/C_p/mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/simulation-automations/references/sd7003/wall/C_p/lower")
u_dir.mkdir(parents=True, exist_ok=True)
l_dir.mkdir(parents=True, exist_ok=True)

eps = 1e-12

for p in src_dir.glob("*.csv"):
    df = pd.read_csv(p, comment="#")
    xcol, ycol = df.columns[0], df.columns[1]

    up = df[df[ycol] > +eps]
    lo = df[df[ycol] < -eps]

    if len(up):
        up.to_csv(u_dir / p.name, index=False)
    if len(lo):
        lo.to_csv(l_dir / p.name, index=False)

    print(p.name, "upper", len(up), "lower", len(lo))
