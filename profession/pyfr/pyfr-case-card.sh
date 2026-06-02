#!/usr/bin/env bash
# Build a small forensic card from a PyFR run directory.
set -euo pipefail

case_dir=${1:-.}
pyfrs=${2:-}
mesh=${3:-}
order=${4:-}
NEWTON_MAX=${5:-}

this_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir="$case_dir/_case_card"
mkdir -p "$outdir"

if [[ -n "$pyfrs" ]]; then
  python "$this_dir/pyfr-h5-extract.py" "$pyfrs" --datasets config stats --outdir "$outdir" > "$outdir/h5_extract.log"
fi

if [[ -n "$mesh" && -n "$order" ]]; then
  python "$this_dir/pyfr-pyfrm-summary.py" "$mesh" --order "$order" --json > "$outdir/pyfrm_summary.json" || true
fi

steps=$(find "$case_dir" -type f \( -name 'dtstats_fdw.csv' -o -name 'dtstats.csv' \) | head -1 || true)
stages=$(find "$case_dir" -type f \( -name 'dtstats-stages.csv' -o -name 'dtstats_stages.csv' \) | head -1 || true)
if [[ -n "$steps" ]]; then
  if [[ -n "$stages" ]]; then
    python "$this_dir/pyfr-implicit-csv-summary.py" --steps "$steps" --stages "$stages" --out "$outdir/csv_summary.md"
  else
    python "$this_dir/pyfr-implicit-csv-summary.py" --steps "$steps" --out "$outdir/csv_summary.md"
  fi
fi

echo "wrote: $outdir"
