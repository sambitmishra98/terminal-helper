import sys
import pandas as pd, numpy as np

p   = sys.argv[1]
col = sys.argv[2]

df = pd.read_csv(p)
dst = f"sqrt-{col}"
df[dst] = np.sqrt(np.clip(df[col].to_numpy(), 0.0, None))  # guard tiny negatives
df.to_csv(p, index=False)
print(f"Wrote column: {dst}")
