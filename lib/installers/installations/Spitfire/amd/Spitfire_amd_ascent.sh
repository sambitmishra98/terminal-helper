#!/usr/bin/env bash
#SBATCH -J "Ascent-setup"
#SBATCH --ntasks=32
#SBATCH --nodes=2
#SBATCH --exclusive
#SBATCH --gpu-bind=closest
#SBATCH --use-min-nodes
#SBATCH --gres=gpu:3
#SBATCH --time=1-00:00:00
#SBATCH --output=amd-ascent-%j.out
#SBATCH --no-requeue
#SBATCH --partition=amd
#SBATCH --cpus-per-gpu=4
#SBATCH --mem-per-gpu=20G
#SBATCH --nodelist=spitfire-ng[28,29]

. /etc/profile.d/modules.sh
. ~/.bashrc

# --------------------------------------------------------------------------
# 1. module / compiler stack
# --------------------------------------------------------------------------
source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh
add_installation_to_path rocm ""      /opt/
add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

# --------------------------------------------------------------------------
# 2. UCX already installed earlier
# --------------------------------------------------------------------------
UCX_VER="master"
add_installation_to_path ucx-rocm "$UCX_VER" "$INSTALLS"

# --------------------------------------------------------------------------
# 3. Open-MPI build
# --------------------------------------------------------------------------
export OMPI_VER="main"
add_installation_to_path ompi-rocm "$OMPI_VER" "$INSTALLS"

source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ascent.sh

export ASCENT_VER="develop"

#download_ascent
#prepare_environment
build_ascent
