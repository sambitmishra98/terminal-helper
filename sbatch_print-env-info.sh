print_env_info() {
    # Only use color if writing to a terminal
    local CYAN="\e[36m"; 
    local GREEN="\e[32m"; 
    local NC="\e[0m"

    mpi_tasks_per_node=$(echo "$SLURM_TASKS_PER_NODE" | sed -e 's/^\([0-9][0-9]*\).*$/\1/')
    np=$((SLURM_JOB_NUM_NODES * mpi_tasks_per_node))

    echo -e "${CYAN}Running on master node:${NC} ${GREEN}$(hostname)${NC}"
    echo -e "${CYAN}Time:              ${NC} ${GREEN}$(date)${NC}"
    echo -e "${CYAN}Current directory: ${NC} ${GREEN}$(pwd)${NC}"
    echo -e "${CYAN}JobID:             ${NC} ${GREEN}$SLURM_JOB_ID${NC}"
    echo -e "${CYAN}======${NC}"
    echo -e "${CYAN}Tasks=${NC}${GREEN}$SLURM_NTASKS${NC}, ${CYAN}nodes=${NC}${GREEN}$SLURM_JOB_NUM_NODES${NC}, ${CYAN}MPI tasks per node=${NC}${GREEN}$mpi_tasks_per_node${NC} ${CYAN}(OMP_NUM_THREADS=${NC}${GREEN}$OMP_NUM_THREADS${CYAN})${NC}"
}
