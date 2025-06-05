#!/usr/bin/env bash

print_env_info() {
    mpi_tasks_per_node=$(echo "$SLURM_TASKS_PER_NODE" | sed -e  's/^\([0-9][0-9]*\).*$/\1/')
    np=$[${SLURM_JOB_NUM_NODES}*${mpi_tasks_per_node}]

    echo "Running on master node: $(hostname)"
    echo "Time: $(date)"
    echo "Current directory: $(pwd)"
    echo -e "JobID: $SLURM_JOB_ID\n======"
    echo -e "Tasks=${SLURM_NTASKS}, nodes=${SLURM_JOB_NUM_NODES}, MPI tasks per node=$(echo $SLURM_TASKS_PER_NODE | sed -e 's/^\([0-9][0-9]*\).*$/\1/')"
    #echo $PATH | tr ':' '\n'
}
