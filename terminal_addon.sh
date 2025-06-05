#!/usr/bin/env bash
# Helper: convenience wrapper to source worktree and venv setup
# Usage: bash terminal_addon.sh <repo-root>
# Requires: environment variables from set_paths (e.g. VENVS)


source ${1}/profession/sambitmishra98_pyfr/setup-worktree.sh
source ${1}/profession/sambitmishra98_pyfr/setup-venv.sh
