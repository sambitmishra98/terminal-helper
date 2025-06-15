#!/usr/bin/env bash
#SBATCH -J "OMPI-setup"
#SBATCH --nodes=2               # build on same 2 V100 nodes
#SBATCH --ntasks=64
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-gpu=4
#SBATCH --exclusive
#SBATCH --partition=all
#SBATCH --time=1-00:00:00
#SBATCH --output=ompi-%j.out
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
source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ompi-git.sh
export OMPI_VER="main"

#clone_openmpi_git "$OMPI_VER"
#autogen_openmpi_git

#configure_openmpi_git
#make_openmpi_git
#install_openmpi_git

add_installation_to_path ompi-cuda "$OMPI_VER" "$INSTALLS"
check_openmpi_git

ompi_info