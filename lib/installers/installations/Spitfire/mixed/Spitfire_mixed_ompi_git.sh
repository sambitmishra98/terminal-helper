
source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh

add_installation_to_path rocm ""      /opt/
add_installation_to_path cuda ""      /usr/local/
add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

export UCX_VER="master"
add_installation_to_path ucx-mixed "$UCX_VER" "$INSTALLS"

source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ompi-git.sh
export OMPI_VER="main"

clone_openmpi_git "$OMPI_VER"
#autogen_openmpi_git

# configure_ompi_mixed_git
# make_openmpi_git
#install_openmpi_git

# add_installation_to_path ompi-mixed "$OMPI_VER" "$INSTALLS"
# check_openmpi_git

# ucx_info -d

# ompi_info
