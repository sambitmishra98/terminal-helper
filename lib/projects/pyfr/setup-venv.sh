#!/usr/bin/env bash
# Helper: bootstrap a PyFR virtual environment and clone
# Usage: source setup-venv.sh then call setup_pyfr_venv <type> <name>
# Requires: SAMBITMISHRA98_PYFR and SAMBITMISHRA98_PYFR_VENVS variables

###############################################################################
# setup_pyfr_venv <venv-type> <venv-name>
# Creates a Python virtual-environment and a *matching* PyFR clone
# under:
#   $SAMBITMISHRA98_PYFR_VENVS/<venv-name>
#   $SAMBITMISHRA98_PYFR/<venv-name>
###############################################################################

setup_pyfr_venv ()
{
    # If already in venv, deactivate
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        echo -e "${C_YELLOW}>>> Deactivating existing virtual-env${C_RESET}"
        deactivate
    fi

    local VENV_TYPE="$1"
    local VENV_NAME="$2"

    ###############  ANSI colours  ###########################################
    local C_RESET="\e[0m"
    local C_GREEN="\e[1;32m"
    local C_YELLOW="\e[1;33m"
    local C_RED="\e[1;31m"
    local C_CYAN="\e[1;36m"
    ##########################################################################

    # --- usage guard --------------------------------------------------------
    if [[ $# -lt 2 ]]; then
        echo -e "${C_RED}Usage:${C_RESET} setup_pyfr_venv <venv-type> <venv-name>"
        return 1
    fi

    # --- path definitions ---------------------------------------------------
    : "${SAMBITMISHRA98_PYFR:?Environment variable SAMBITMISHRA98_PYFR not set}"
    : "${SAMBITMISHRA98_PYFR_VENVS:?Environment variable SAMBITMISHRA98_PYFR_VENVS not set}"

    local venv_dir="${SAMBITMISHRA98_PYFR_VENVS}${VENV_NAME}/"
    local pyfr_dir="${SAMBITMISHRA98_PYFR}${VENV_NAME}/"

    # --- toolchain checks ---------------------------------------------------
    if ! command -v python3 &>/dev/null; then
        echo -e "${C_RED}>>> python3 not found in PATH${C_RESET}"
        return 1
    fi
    if ! command -v mpiexec &>/dev/null || ! command -v mpicc &>/dev/null; then
        echo -e "${C_RED}>>> MPI not found in PATH (mpiexec/mpicc required)${C_RESET}"
        return 1
    fi
    if command -v ucx_info &>/dev/null; then
        echo -e "${C_GREEN}>>> UCX available${C_RESET}"
    else
        echo -e "${C_YELLOW}>>> UCX not found; continuing without UCX${C_RESET}"
    fi

    if ! python3 - <<'PY'
import sys
sys.exit(0 if sys.version_info >= (3, 12) else 1)
PY
    then
        echo -e "${C_RED}>>> Python 3.12+ is required${C_RESET}"
        return 1
    fi

    echo -e "${C_CYAN}=== Pre-flight check =======================================${C_RESET}"
    # Virtual-env directory check
    if [[ -e "${venv_dir}" ]]; then
        echo -e "${C_RED}Virtual-env already exists → ${venv_dir}${C_RESET}"
        return 1
    fi
    echo -e "${C_GREEN}Virtual-env will be created → ${venv_dir}${C_RESET}"

    # PyFR directory check
    if [[ -e "${pyfr_dir}" ]]; then
        echo -e "${C_RED}PyFR clone already exists → ${pyfr_dir}${C_RESET}"
        return 1
    fi
    echo -e "${C_GREEN}PyFR repo will be cloned → ${pyfr_dir}${C_RESET}"
    echo -e "${C_CYAN}===========================================================${C_RESET}"

    # ------------------------------------------------------------------------
    # 1. Create / activate virtual-env
    # ------------------------------------------------------------------------
    echo -e "${C_CYAN}>>> Creating virtual-env${C_RESET}"
    python3 -m venv "${venv_dir}" || { echo -e "${C_RED}venv creation failed${C_RESET}"; return 1; }

    # shellcheck disable=SC1090
    source "${venv_dir}/bin/activate"

    echo -e "${C_CYAN}>>> Upgrading venv tooling${C_RESET}"
    python -m pip install --upgrade pip setuptools wheel || {
        echo -e "${C_RED}pip tooling upgrade failed${C_RESET}"
        return 1
    }

    echo -e "${C_CYAN}>>> Installing mpi4py from source${C_RESET}"
    MPICC="${MPICC:-mpicc}" python -m pip install --no-cache-dir --no-binary=mpi4py mpi4py || {
        echo -e "${C_RED}mpi4py install failed${C_RESET}"
        return 1
    }

    # ------------------------------------------------------------------------
    # 2. Clone / update PyFR working copy
    # ------------------------------------------------------------------------
    echo -e "${C_CYAN}>>> Cloning PyFR fork${C_RESET}"
    git clone --branch "${VENV_NAME}" --single-branch https://github.com/sambitmishra98/PyFR.git "${pyfr_dir}" \
        || { echo -e "${C_RED}git clone failed${C_RESET}"; return 1; }

    # Build in editable/develop mode
    echo -e "${C_CYAN}>>> Building PyFR in-place (pip install -e .)${C_RESET}"
    ( cd "${pyfr_dir}" && python -m pip install --no-cache-dir -e . ) \
        || { echo -e "${C_RED}PyFR develop install failed${C_RESET}"; return 1; }

    echo -e "${C_GREEN}=== PyFR virtual-env '${VENV_NAME}' ready${C_RESET}"
}

###############################################################################
# update_feature_branch  <branch> [remote]
# Rebase the current feature branch (or <branch>) onto origin/develop
# and publish the cleaned history with --force-with-lease.
###############################################################################
update_feature_branch () {
    local br="${1:-$(git symbolic-ref --quiet --short HEAD)}"
    local remote="${2:-origin}"

    # Safety guard – must be on a feature/* branch
    [[ "$br" =~ ^feature/ ]] || {
        echo "Not a feature branch: $br"; return 1; }

    # Always work from repo root
    git rev-parse --show-toplevel &>/dev/null || return 1
    cd "$(git rev-parse --show-toplevel)" || return 1

    git config pull.rebase true
    git config rebase.autoStash true

    echo ">>> Fast-forwarding $remote/develop"
    git fetch "$remote" &&
    git switch develop &&
    git pull --ff-only "$remote" develop       || return 1

    echo ">>> Rebasing $br onto develop"
    git switch "$br"                           || return 1
    git rebase "$remote"/develop               || return 1

    echo ">>> Publishing cleaned branch"
    git push --force-with-lease "$remote" "$br"
}

###############################################################################
# setup_pyfr_venv_with_deps <venv-type> <venv-name> <dep1> [dep2 …]
###############################################################################
setup_pyfr_venv_with_deps () {
    local vtype="$1"; local vname="$2"; shift 2
    local deps=("$@")

    for dep in "${deps[@]}"; do
        # ensure the dependent feature branch is clean / up-to-date
        ( cd "${SAMBITMISHRA98_PYFR}${dep}/" 2>/dev/null && \
          update_feature_branch "feature/${dep}" ) || true
        setup_pyfr_venv "$vtype" "$dep"            || return 1
    done

    # finally create / reuse the requested venv
    setup_pyfr_venv "$vtype" "$vname"
}