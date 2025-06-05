#!/usr/bin/env bash
#SBATCH -J "make"
#SBATCH --ntasks=24
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --use-min-nodes
#SBATCH --time=1-00:00:00
#SBATCH --output=J%j_ffi.out
#SBATCH --no-requeue
#SBATCH --partition=amd
#SBATCH --mem=20G
#SBATCH --nodelist=spitfire-ng[21]

source /mnt/share/sambit98/EFFORTS/submarine/testbed-submarine/configs-and-scripts/setup_environment_ng29.sh

source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/installations/python.sh

export UCX_WARN_UNUSED_ENV_VARS=n

set_python_version

#download_python
# extract_python
# configure_python
# build_python
install_python

#echo "[ALL DONE] Ascent is ready for MPI in $prefix"
