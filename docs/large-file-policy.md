# Large-file policy

Large artifacts belong in scratch, not in this repository. This includes:

- Meshes and geometry files (e.g., `*.msh`)
- PyFR meshes and solutions (`*.pyfrm`, `*.pyfrs`)
- Visualization outputs (`*.vtu`)
- Large CSVs, logs, and case outputs

Use `/scratch/supplementary` for reusable inputs and `/scratch/EFFORTS` for
actual runs and results. These locations are not meant to be synced by default.
