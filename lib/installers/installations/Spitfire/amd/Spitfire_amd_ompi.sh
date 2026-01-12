#!/usr/bin/env bash
#SBATCH -J "OMPI-setup"
#SBATCH --ntasks=32
#SBATCH --nodes=2
#SBATCH --exclusive
#SBATCH --gpu-bind=closest
#SBATCH --use-min-nodes
#SBATCH --gres=gpu:3
#SBATCH --time=1-00:00:00
#SBATCH --output=amd-ompi-git-main-%j.out
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
#add_installation_to_path cuda ""      /usr/local/
add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

export UCX_VER="master"
add_installation_to_path ucx-rocm "$UCX_VER" "$INSTALLS"

source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ompi-git.sh
export OMPI_VER="main"

#clone_openmpi_git "$OMPI_VER"
#autogen_openmpi_git

# configure_openmpi_git ucx,rocm
# make_openmpi_git
#install_openmpi_git

add_installation_to_path ompi-rocm "$OMPI_VER" "$INSTALLS"
check_openmpi_git

ucx_info -d

ompi_info
