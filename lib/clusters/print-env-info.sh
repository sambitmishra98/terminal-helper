#!/usr/bin/env bash
# Helper: print key SLURM environment details for diagnostics
# Usage: source print-env-info.sh then call print_env_info
# Requires: SLURM_JOB_NUM_NODES, SLURM_TASKS_PER_NODE variables

source "$(dirname "${BASH_SOURCE[0]}")/../colors.sh"

print_env_info() {
    mpi_tasks_per_node=$(echo "$SLURM_TASKS_PER_NODE" | sed -e 's/^\([0-9][0-9]*\).*$/\1/')

    echo -e "${BOLD}${BLUE}Running on master node:${RESET} $(hostname)"
    echo -e "${BOLD}${BLUE}Time:${RESET} $(date)"
    echo -e "${BOLD}${BLUE}Current directory:${RESET} $(pwd)"
    echo -e "${MAGENTA}JobID:${RESET} $SLURM_JOB_ID\n${MAGENTA}======${RESET}"
    echo -e "${CYAN}Tasks=${SLURM_NTASKS}, nodes=${SLURM_JOB_NUM_NODES}, MPI tasks per node=${mpi_tasks_per_node}${RESET}"
    #echo $PATH | tr ':' '\n'
}
