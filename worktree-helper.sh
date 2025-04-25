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
  • ${YELLOW}--base <case/branch>${NC}    – the name of the case branch (e.g. case/c3900)
  • ${YELLOW}--trunk <trunk-branch>${NC} – the upstream branch to start from (e.g. develop)
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
  local worktree_folder="${base_branch//\//-}"    # case/c3900 → case-c3900
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
  echo -e "${BLUE}Recreating worktree '${wt_path}' from origin/${trunk_branch}…${NC}"
  git worktree remove "$wt_path" 2>/dev/null || true
  rm -rf "$wt_path"
  git worktree add "$wt_path" origin/"$trunk_branch" -B "$base_branch"
  echo -e "${GREEN}✓ Worktree ready at ${wt_path}${NC}"

  #── 3) Merge each feature in order ──────
  echo
  echo -e "${BLUE}Merging in feature branches:${NC}"
  pushd "$wt_path" >/dev/null
  for feat in "${add_branches[@]}"; do
    echo -e "  ${YELLOW}→${NC} Merging ${feat} into ${base_branch}…"
    git fetch origin "$feat"
    git merge --no-ff --no-edit origin/"$feat"
  done
  popd >/dev/null

  #── Done ────────────────────────────────
  echo
  echo -e "${GREEN}✅ ${base_branch} is now: ${trunk_branch} + ${add_branches[*]}${NC}"
}
