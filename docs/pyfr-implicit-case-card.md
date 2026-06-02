# PyFR implicit case-card workflow

This workflow records the small, stable forensic information needed to compare PyFR implicit runs across TGV, C3900, submarine, and future cases.

The goal is not to archive large outputs in this repository. Meshes, solution files, CSV files, and logs remain in `/scratch/EFFORTS`, `/mnt/share`, or cluster storage. This repository stores reusable scripts and documentation only.

## Purpose

For every implicit run, create a small `_case_card/` directory that answers:

- What exact PyFR config was used?
- What runtime stats were embedded in the written solution file?
- What mesh scale was used?
- What partitioning was used?
- Did the run advance cleanly?
- Did Newton converge, or did it hit `newton-max-iter`?
- Was GMRES or Newton the dominant cost?
- Was a preconditioner used, rebuilt, or stale?
- What was the wall-time cost per accepted physical time?

## Standard output layout

For a run directory such as:

```text
try-2/
  csvs/
  pyfrss/
  ...
```

create:

```text
try-2/_case_card/
  <solution>.config.ini
  <solution>.stats.txt
  gmsh_summary.json
  gmsh_summary.ini
  pyfrm_summary.json
  pyfrm_summary.ini
  implicit_csv_summary.md
```

The extracted `<solution>.config.ini` is the ground-truth PyFR input. Prefer it over nearby `*.ini` files because it is embedded in the actual `*.pyfrs` file that was written by PyFR.

Do not append mesh summaries into the extracted PyFR config. Keep the extracted config clean so it can be reused as a PyFR input if needed.

## Required scripts

Scripts live in:

```text
profession/pyfr/
```

Expected scripts:

```text
pyfr-h5-extract.py
pyfr-gmsh-summary.py
pyfr-pyfrm-summary.py
pyfr-implicit-csv-summary.py
pyfr-json-to-ini.py
```

## HDF5 note

On some clusters, `h5dump` from older HDF5 stacks may fail on newer PyFR mesh or solution files. Load the HDF5 module that works for the current PyFR format. On Spitfire, HDF5 2.1.1 worked for the tested C3900 case.

Check with:

```bash
which h5dump
h5dump -V
```

## Standard commands

Set these variables per case:

```bash
CASE=/mnt/share/sambit98/EFFORTS/c3900_newversion/fdw/02_c3900
RUN=$CASE/try-2
SOLN=$RUN/pyfrss/cyl-imp-10.00.pyfrs
PYFRM=$CASE/mesh/t3.pyfrm
MSH=$CASE/mesh/t3-merged_corrected.msh
ORDER=4
NEWTON_MAX=40
CARD=$RUN/_case_card
mkdir -p "$CARD"
```

Extract the actual config and stats from the solution file:

```bash
python profession/pyfr/pyfr-h5-extract.py \
  "$SOLN" \
  --datasets config stats \
  --outdir "$CARD"
```

Summarise the PyFR mesh file:

```bash
python profession/pyfr/pyfr-pyfrm-summary.py \
  "$PYFRM" \
  --order "$ORDER" \
  --json > "$CARD/pyfrm_summary.json"

python profession/pyfr/pyfr-json-to-ini.py \
  "$CARD/pyfrm_summary.json" \
  --section pyfrm-summary \
  > "$CARD/pyfrm_summary.ini"
```

Summarise the original Gmsh mesh if available:

```bash
python profession/pyfr/pyfr-gmsh-summary.py \
  "$MSH" \
  --json > "$CARD/gmsh_summary.json"

python profession/pyfr/pyfr-json-to-ini.py \
  "$CARD/gmsh_summary.json" \
  --section gmsh-summary \
  > "$CARD/gmsh_summary.ini"
```

Summarise implicit solver diagnostics:

```bash
python profession/pyfr/pyfr-implicit-csv-summary.py \
  --steps "$RUN/csvs/dtstats_fdw.csv" \
  --stages "$RUN/csvs/dtstats-stages.csv" \
  --newton-max "$NEWTON_MAX" \
  --out "$CARD/implicit_csv_summary.md"
```

## Interpretation rules

### Correctness

Do not judge correctness from accepted steps alone. With `controller = none`, a run may accept all steps even when Newton repeatedly reaches `newton-max-iter`.

Use solution norms, conserved quantities, integrated forces, residual trends, and explicit-vs-implicit comparison at matched physical times.

### Robustness

Check:

- accepted and rejected step counts
- non-finite residuals
- Newton cap fraction
- Krylov iteration distribution
- preconditioner rebuilds
- preconditioner `gamma*dt` drift

### Performance

Normalize by accepted physical time, not raw wall time alone.

Useful quantities:

- wall time per accepted physical time
- Newton iterations per stage
- Krylov iterations per Newton solve
- preconditioner applications per stage
- preconditioner builds per accepted physical time
- RHS evaluations per accepted physical time

## Current C3900 lesson

For the tested C3900 run, the fixed-dt trapezium/no-preconditioner run advances cleanly, but Newton reaches the cap for most stages. Therefore, it is a stable advancing run, but not yet a trusted tuned implicit baseline.

Before enabling PI, throughput, or Block-Jacobi, first understand why Newton stagnates near the single-precision residual floor.
