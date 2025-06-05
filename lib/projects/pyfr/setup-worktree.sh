#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup-worktree.sh  —  Manage a local Git work-tree for a PyFR branch
#
# Usage:
#   setup-worktree.sh <branch> [<remote-url>]
#
#   <branch>      The branch name to check out as a work-tree
#   <remote-url>  Optional. Defaults to the upstream configured in the repo
#
# Environment (assumed from set_paths):
#   SCRATCH, PYFR_BRANCHES
#
# Outcome:
#   • Creates  $PYFR_BRANCHES/<branch>
#   • Adds the work-tree if not already present
#   • Prints the path so caller scripts can cd into it
#
# Exit codes:
#   0   success
#   1   usage / arg error
#   2   git error
# ---------------------------------------------------------------------------
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <branch> [remote-url]" >&2
    exit 1
}

# ── 1. parse args ────────────────────────────────────────────────────────────
[[ $# -ge 1 ]] || usage
BRANCH=$1; shift
REMOTE_URL=${1-}

[[ -n ${SCRATCH-}        ]] || { echo "SCRATCH not set";  exit 1; }
[[ -n ${PYFR_BRANCHES-}  ]] || { echo "PYFR_BRANCHES not set"; exit 1; }

DEST="$PYFR_BRANCHES/$BRANCH"
mkdir -p "$PYFR_BRANCHES"

# ── 2. ensure upstream repo exists ───────────────────────────────────────────
if [[ -n $REMOTE_URL ]]; then
    if [[ ! -d "$PYFR_BRANCHES/.bare" ]]; then
        echo "Cloning bare mirror…"
        git clone --bare "$REMOTE_URL" "$PYFR_BRANCHES/.bare" || exit 2
    fi
    GIT_DIR="$PYFR_BRANCHES/.bare"
else
    # fall back to first upstream of an existing bare mirror
    GIT_DIR="$PYFR_BRANCHES/.bare"
    [[ -d $GIT_DIR ]] || { echo "No remote URL and no bare repo"; exit 1; }
fi

# ── 3. add work-tree if needed ───────────────────────────────────────────────
if git --git-dir="$GIT_DIR" worktree list | grep -qF " $DEST "; then
    echo "✓ work-tree already exists → $DEST"
else
    git --git-dir="$GIT_DIR" worktree add "$DEST" "$BRANCH" || exit 2
    echo "✓ work-tree created → $DEST"
fi

echo "$DEST"
