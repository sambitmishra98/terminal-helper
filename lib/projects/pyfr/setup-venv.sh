#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup-venv.sh — Create (or reuse) a Python virtual-env for PyFR work
#
# Usage:
#   setup-venv.sh <env-name> [python-exe] [requirements.txt]
#
#   <env-name>        Name under $VENVS (e.g., pyfr-dev)
#   python-exe        Path to python interpreter (default: python3.12)
#   requirements.txt  Optional requirements file to pip install
#
# Environment (assumed from set_paths):
#   VENVS
#
# The script is *idempotent*: re-running with the same name just prints path.
# ---------------------------------------------------------------------------
set -euo pipefail

usage() { echo "Usage: $(basename "$0") <env> [python] [reqs.txt]" >&2; exit 1; }

[[ $# -ge 1 ]] || usage
NAME=$1; shift
PYEXE=${1:-python3.12}; shift || true
REQS=${1:-}

[[ -n ${VENVS-} ]] || { echo "VENVS not set"; exit 1; }

DEST="$VENVS/$NAME"
if [[ ! -d $DEST ]]; then
    echo "Creating venv at $DEST with $PYEXE"
    "$PYEXE" -m venv "$DEST"
else
    echo "✓ venv already exists → $DEST"
fi

# shellcheck source=/dev/null
source "$DEST/bin/activate"

if [[ -n $REQS ]]; then
    echo "Installing requirements from $REQS"
    pip install --upgrade pip
    pip install -r "$REQS"
fi

echo "$DEST"
