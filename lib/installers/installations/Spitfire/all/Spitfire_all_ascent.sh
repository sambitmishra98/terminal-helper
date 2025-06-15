#!/usr/bin/env bash
#SBATCH -J "Ascent-setup"
#SBATCH --nodes=2               # build on same 2 V100 nodes
#SBATCH --ntasks=64
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-gpu=4
#SBATCH --exclusive
#SBATCH --partition=all
#SBATCH --time=1-00:00:00
#SBATCH --output=ascent-%j.out
#SBATCH --nodelist=spitfire-ng[19,20]

. /etc/profile.d/modules.sh
. ~/.bashrc

# --------------------------------------------------------------------------
# 1. module / compiler stack
# --------------------------------------------------------------------------
source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh
add_installation_to_path cuda ""      /usr/local/
add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

# --------------------------------------------------------------------------
# 2. UCX already installed earlier
# --------------------------------------------------------------------------
UCX_VER="master"
add_installation_to_path ucx-cuda "$UCX_VER" "$INSTALLS"

# --------------------------------------------------------------------------
# 3. Open-MPI build
# --------------------------------------------------------------------------
export OMPI_VER="main"
add_installation_to_path ompi-cuda "$OMPI_VER" "$INSTALLS"

source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ascent.sh

export ASCENT_VER="develop"

download_ascent
#prepare_environment
build_ascent
