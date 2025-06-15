#!/usr/bin/env bash
#SBATCH -J "UCX-setup"
#SBATCH --ntasks=64
#SBATCH --nodes=2
#SBATCH --exclusive
#SBATCH --gpu-bind=closest
#SBATCH --use-min-nodes
#SBATCH --gres=gpu:4
#SBATCH --time=1-00:00:00
#SBATCH --output=ucx-%j.out
#SBATCH --no-requeue
#SBATCH --partition=all
#SBATCH --cpus-per-gpu=4
#SBATCH --mem-per-gpu=20G
#SBATCH --nodelist=spitfire-ng[19,20]

. /etc/profile.d/modules.sh
. ~/.bashrc

source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh

add_installation_to_path cuda ""      /usr/local/
add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ucx-git.sh

export UCX_VER="master"
# clone_ucx_git $UCX_VER  # clones UCX git repo into $EXTRACTS
# autogen_ucx_git          # generates ./configure
# configure_ucx_git        # picks up CUDA + verbs
# make_ucx_git             # compiles in parallel
# install_ucx_git          # copies into $INSTALLS

add_installation_to_path ucx-cuda "$UCX_VER" "$INSTALLS"

check_ucx_git            # prints ucx_info summary
