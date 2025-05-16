#!/bin/bash
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

source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/installations/libffi.sh

export UCX_WARN_UNUSED_ENV_VARS=n

set_libffi_version

download_libffi
extract_libffi
configure_libffi
build_libffi
install_libffi

#echo "[ALL DONE] Ascent is ready for MPI in $prefix"
