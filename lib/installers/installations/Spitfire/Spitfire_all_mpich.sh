#!/usr/bin/env bash
#SBATCH -J "MPICH-setup"
#SBATCH --ntasks=64
#SBATCH --nodes=2
#SBATCH --exclusive
#SBATCH --gpu-bind=closest
#SBATCH --use-min-nodes
#SBATCH --gres=gpu:4
#SBATCH --time=1-00:00:00
#SBATCH --output=tgv-lb-%j.out
#SBATCH --no-requeue
#SBATCH --partition=all
#SBATCH --cpus-per-gpu=4
#SBATCH --mem-per-gpu=20G
#SBATCH --nodelist=spitfire-ng[19,20]

. /etc/profile.d/modules.sh
. ~/.bashrc


# Source all exports
source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/profession/set-paths-dir.sh

# Source all functions
source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/installations-linker.sh
source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/clusters/print-env-info.sh

source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/installations/mpich.sh
source /mnt/share/sambit98/.github/sambitmishra98/terminal-helper/installations/ucx.sh

# Call above stuff
set_paths "/mnt/share/sambit98/"
print_paths
print_env_info

# Source all libraries
add_installation_to_path cuda  "" "/usr/local"
add_installation_to_path "gcc"  "12.3.0"   "$SCRATCH/.local-spitfire/pkg/"
set_ucx_version
set_mpich_version
add_installation_to_path ucx-cuda "1.18.0" "$INSTALLS"
add_installation_to_path mpich    "4.3.0" "$INSTALLS"

export UCX_WARN_UNUSED_ENV_VARS=n

#download_mpich     || exit 1
#extract_mpich      || exit 1
#configure_mpich        || exit 1
#make_mpich        || exit 1
#install_mpich        || exit 1
check_mpich