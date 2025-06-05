#!/usr/bin/env bash
# Helper: bootstrap a PyFR virtual environment and clone
# Usage: source setup-venv.sh then call setup_pyfr_venv <type> <name>
# Requires: VENVS and SAMBITMISHRA98_PYFR variables

###############################################################################
# setup_pyfr_venv <venv-type> <venv-name>
# Creates (or re-uses) a Python virtual-environment and a *matching* PyFR clone
# under:
#   $VENVS/<venv-type>-<venv-name>
#   $SAMBITMISHRA98_PYFR/<venv-type>-<venv-name>
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
    : "${VENVS:?Environment variable VENVS not set}"
    : "${SAMBITMISHRA98_PYFR:?Environment variable SAMBITMISHRA98_PYFR not set}"

    local venv_dir="${VENVS}/${VENV_TYPE}-${VENV_NAME}"
    local pyfr_dir="${SAMBITMISHRA98_PYFR}/${VENV_TYPE}-${VENV_NAME}"

    echo -e "${C_CYAN}=== Pre-flight check =======================================${C_RESET}"
    # Virtual-env directory check
    if [[ -d "${venv_dir}" ]]; then
        echo -e "${C_YELLOW}Virtual-env exists → ${venv_dir}${C_RESET}"
        read -rp "    Re-use it? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo -e "${C_RED}Aborting; existing venv rejected by user.${C_RESET}"
            return 1
        fi
    else
        echo -e "${C_GREEN}Virtual-env will be created → ${venv_dir}${C_RESET}"
    fi

    # PyFR directory check
    if [[ -d "${pyfr_dir}" ]]; then
        echo -e "${C_YELLOW}PyFR clone exists → ${pyfr_dir}${C_RESET}"
        read -rp "    Re-use it? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo -e "${C_RED}Aborting; existing PyFR clone rejected by user.${C_RESET}"
            return 1
        fi
    else
        echo -e "${C_GREEN}PyFR repo will be cloned → ${pyfr_dir}${C_RESET}"
    fi
    echo -e "${C_CYAN}===========================================================${C_RESET}"

    # ------------------------------------------------------------------------
    # 1. Create / activate virtual-env
    # ------------------------------------------------------------------------
    if [[ ! -d "${venv_dir}" ]]; then
        echo -e "${C_CYAN}>>> Creating virtual-env${C_RESET}"
        python3 -m venv "${venv_dir}" || { echo -e "${C_RED}venv creation failed${C_RESET}"; return 1; }
    else
        echo -e "${C_CYAN}>>> Re-using existing virtual-env${C_RESET}"
    fi

    # shellcheck disable=SC1090
    source "${venv_dir}/bin/activate"

    echo -e "${C_CYAN}>>> Boot-strapping pip + core deps${C_RESET}"
    python -m pip install --upgrade pip        &&
    python -m pip install --no-cache-dir mpi4py &&
    python -m pip install pyfr setuptools       &&
    python -m pip uninstall -y pyfr             || {
        echo -e "${C_RED}pip bootstrap failed${C_RESET}"
        return 1
    }

    # ------------------------------------------------------------------------
    # 2. Clone / update PyFR working copy
    # ------------------------------------------------------------------------
    if [[ ! -d "${pyfr_dir}" ]]; then
        echo -e "${C_CYAN}>>> Cloning PyFR fork${C_RESET}"
        git -C "${SAMBITMISHRA98_PYFR}" clone https://github.com/sambitmishra98/PyFR.git "${pyfr_dir}" \
            || { echo -e "${C_RED}git clone failed${C_RESET}"; return 1; }
    else
        echo -e "${C_CYAN}>>> Using existing PyFR working copy${C_RESET}"
    fi

    # Build in editable/develop mode
    echo -e "${C_CYAN}>>> Building PyFR in-place (python setup.py develop)${C_RESET}"
    ( cd "${pyfr_dir}" && python setup.py develop ) \
        || { echo -e "${C_RED}PyFR develop install failed${C_RESET}"; return 1; }

    echo -e "${C_GREEN}=== PyFR virtual-env '${VENV_TYPE}-${VENV_NAME}' ready${C_RESET}"
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
        ( cd "${SAMBITMISHRA98_PYFR}/${vtype}-${dep}" 2>/dev/null && \
          update_feature_branch "feature/${dep}" ) || true
        setup_pyfr_venv "$vtype" "$dep"            || return 1
    done

    # finally create / reuse the requested venv
    setup_pyfr_venv "$vtype" "$vname"
}