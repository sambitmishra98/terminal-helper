#!/usr/bin/env bash
#SBATCH -J "H1_scale"
#SBATCH --ntasks=9
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --gpu-bind=closest
#SBATCH --use-min-nodes
#SBATCH --gres=gpu:3
#SBATCH --time=1-00:00:00
#SBATCH --output=tgv-lb-%j.out
#SBATCH --no-requeue
#SBATCH --partition=amd
#SBATCH --cpus-per-gpu=1
#SBATCH --mem-per-gpu=20G
#SBATCH --nodelist=spitfire-ng29

. /etc/profile.d/modules.sh
. ~/.bashrc

export OMP_NUM_THREADS=4

source /mnt/share/sambit98/EFFORTS/online-load-balancing/LoadBalancer2-ng21.sh

numnodes=$SLURM_JOB_NUM_NODES
mpi_tasks_per_node=$(echo "$SLURM_TASKS_PER_NODE" | sed -e  's/^\([0-9][0-9]*\).*$/\1/')
np=$[${SLURM_JOB_NUM_NODES}*${mpi_tasks_per_node}]

echo "Running on master node: `hostname`"
echo "Time: `date`"
echo "Current directory: `pwd`"
echo -e "JobID: $SLURM_JOB_ID\n======"
echo -e "Tasks=${SLURM_NTASKS},nodes=${SLURM_JOB_NUM_NODES}, mpi_tasks_per_node=${mpi_tasks_per_node} (OMP_NUM_THREADS=$OMP_NUM_THREADS)"

#echo $PATH | tr ':' '\n'
export PYFR_METIS_LIBRARY_PATH=$SCRATCH/.local-spitfire/git/metis/lib/libmetis.so
echo "PYFR_METIS_LIBRARY_PATH=$PYFR_METIS_LIBRARY_PATH"

# Run subscript

export meshf=etype-hex_order-6_dof-40000000.pyfrm
export inif=conf.ini
export partname=END50

export UCX_WARN_UNUSED_ENV_VARS=n

CMD="pyfr partition reconstruct ${meshf} writer-50.pyfrs $partname"
echo $CMD
eval $CMD
srun --mpi=pmi2 --cpu_bind=none -n ${SLURM_NTASKS} ./H3O6.sh

echo "Dumping wall-time stats from output files:"
for i in {0..2} ; do 
    echo "==> writer-$i.pyfrs:"
    h5dump -d /stats writer-$i.pyfrs | grep "wall-time"
done

# Compute and print differences between writer timings.
arr=( $(for i in {0..2}; do 
         h5dump -d /stats writer-${i}.pyfrs \
         | awk '/wall-time =/ {wt=$NF} /plugin-wall-time-common =/ {wc=$NF} /plugin-wall-time-writer =/ {ww=$NF} END {print wt - wc - ww}'; 
      done) )
echo "Time differences between writer outputs:"
for i in {0..1}; do 
    awk -v a="${arr[i]}" -v b="${arr[i+1]}" 'BEGIN { printf "Difference: %.4f\n", b - a }'
done
