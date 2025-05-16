#!/usr/bin/env bash
#
# Place this in your ~/.bashrc or source it at the top of your script.
#
# Usage:
#   setup_worktree \
#     --base  case/c3900 \
#     --trunk develop \
#     --add   feature/foo \
#     --add   feature/bar


setup_worktree() {
  #── Colours ─────────────────────────────
  local RED='\e[31m' GREEN='\e[32m' YELLOW='\e[33m' BLUE='\e[34m' NC='\e[0m'

  #── Arg parsing ─────────────────────────
  local base_branch trunk_branch
  local add_branches=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --base)   base_branch=$2; shift 2;;
      --trunk)  trunk_branch=$2; shift 2;;
      --add)    add_branches+=("$2"); shift 2;;
      *)        echo -e "${RED}❌ Unknown argument: $1${NC}"; return 1;;
    esac
  done

  #── Sanity check ─────────────────────────
  if [[ -z "${base_branch:-}" || -z "${trunk_branch:-}" || "${#add_branches[@]}" -eq 0 ]]; then
    cat <<EOF >&2
  ${RED}❌ Missing required arguments${NC}

  You must supply:
    • ${YELLOW}--base <case/branch>${NC}   – name of case branch (case-c200)
    • ${YELLOW}--trunk <trunk-branch>${NC} – upstream branch (develop)
    • ${YELLOW}--add <feature-branch>${NC} – at least one feature branch to merge

  Example:
    setup_worktree \\
      --base  case/c3900   \\
      --trunk develop      \\
      --add   feature/foo  \\
      --add   feature/bar

EOF
    return 1
  fi

  # If python3 not present in the venv location, error
  if [[ ! -f "${VENVS}/${base_branch}/bin/python3" ]]; then
    echo -e "${RED}❌ venv missing: ${VENVS}/${base_branch}/bin/python3${NC}"
    return 1
  fi


  cd ${SAMBITMISHRA98_PYFR}/develop

  #── Ensure we’re in a Git repository ─────
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}❌ Not inside a Git repository. cd into your PyFR clone and retry.${NC}"
    return 1
  fi

  #── Compute repo root and parent ────────
  local repo_root parent_dir
  repo_root=$(git rev-parse --show-toplevel)
  parent_dir=$(dirname "$repo_root")

  #── Derive worktree path ───────────────
  local worktree_folder="${base_branch}"
  local wt_path="${parent_dir}/${worktree_folder}"

  #── Prevent self-deletion ──────────────
  if [[ "$repo_root" == "$wt_path" ]]; then
    echo -e "${RED}❌ You're currently in '${wt_path}', which is about to be removed.${NC}"
    echo -e "   Please run this from a separate clone directory, not inside the target worktree."
    return 1
  fi

  echo -e "${BLUE}── Setting up worktree for '${base_branch}' → ${wt_path} ──${NC}"

  #── 1) Fetch trunk ──────────────────────
  echo -e "${BLUE}Fetching trunk '${trunk_branch}'…${NC}"
  git fetch origin "$trunk_branch"

  #── 2) (Re)create the worktree ──────────
  echo -e "${BLUE}Pruning any existing worktree at '${wt_path}'…${NC}"
  # remove the worktree registration (force in case it’s still busy)
  git worktree remove --force "$wt_path" 2>/dev/null || true
  # garbage-collect any stray entries
  git worktree prune --expire=now 2>/dev/null || true
  # remove the directory itself
  rm -rf "$wt_path"

  echo -e "${BLUE}Creating fresh worktree '${wt_path}' from origin/${trunk_branch}…${NC}"
  if ! git worktree add "$wt_path" origin/"$trunk_branch" -B "$base_branch"; then
    echo -e "${RED}❌ Failed to add worktree – aborting${NC}"
    return 1
  fi
  echo -e "${GREEN}✓ Worktree ready at ${wt_path}${NC}"

  #── 3) Merge each feature in order ──────
  echo
  echo -e "${BLUE}Merging in feature branches:${NC}"
  pushd "$wt_path" >/dev/null
  for feat in "${add_branches[@]}"; do
    echo -e "  ${YELLOW}→${NC} Merging ${feat} into ${base_branch}…"
    git fetch origin "$feat"


    git merge --no-ff --no-edit origin/"$feat"



#     if ! git merge --no-ff --no-edit origin/"$feat"; then
#       echo -e "${RED}❌ Merge conflict in ${feat}. Aborting further merges.${NC}"
#       popd >/dev/null
#       return 1
#     fi




  done
  popd >/dev/null

  #── Done ────────────────────────────────
  echo
  echo -e "${GREEN}✅ ${base_branch} is now: ${trunk_branch} + ${add_branches[*]}${NC}"
  source "${VENVS}/${base_branch}/bin/activate"

  cd ${SAMBITMISHRA98_PYFR}/${base_branch}

  python3 setup.py develop

}

setup_worktree_testbed() {
    local RED='\e[31m' GREEN='\e[32m' YELLOW='\e[33m' BLUE='\e[34m' NC='\e[0m'

    local caseloc=$(basename "$PWD")

    # Save the current directory
    local current_dir=$(pwd)


    # Ensure we’re in testbed-<casename>
    if [[ ! $caseloc =~ ^testbed- ]]; then
        echo -e "${RED}ERROR: This script must be run from a testbed directory.${NC}"
        echo -e "${YELLOW}Example: cd /scratch/EFFORTS/submarine/testbed-c200${NC}"
    fi

    local casename=${caseloc#testbed-}
    if [ -z "$casename" ]; then
        echo "Error: casename is not set."
    fi

    # Use passed-in feature names or fall back to defaults
    local features=("$@")
    if [ ${#features[@]} -eq 0 ]; then
      echo "Error: No feature names provided."
      echo "Usage: setup_worktree_in_testbed <feature1> <feature2> ..."
      echo "Example: setup_worktree_in_testbed pseudodt-writer pseudodt-stats"
    fi

    # Construct --add arguments
    local add_args=()
    for feat in "${features[@]}"; do
        add_args+=(--add "feature/$feat")
    done

    # Invoke setup_worktree and cd into testbed
    setup_worktree --base "worktree-${casename}" --trunk develop "${add_args[@]}"
    cd $current_dir


    # Grab the venv name (e.g. “worktree-c200”)
    venv_name=$(basename "${VIRTUAL_ENV:-}")

    # Find where pip installed pyfr, then grab its leaf directory
    pyfr_loc=$(pip3 show pyfr | awk '/^Location:/{print $2}')
    branch_name=$(basename "$pyfr_loc")

    # Compare and fail if they differ
    if [ "$branch_name" != "$venv_name" ]; then
      >&2 echo "ERROR: Active venv is '$venv_name' but PyFR is loaded from '$branch_name'"
    else
      echo -e "${GREEN}✓ Active venv is '$venv_name' and PyFR is loaded from '$branch_name'${NC}"
    fi
}
