source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ompi-git.sh
export OMPI_VER="main"

clone_openmpi_git "$OMPI_VER"
autogen_openmpi_git

configure_openmpi_git
make_openmpi_git
install_openmpi_git


add_installation_to_path ompi-cuda-rocm main "$INSTALLS"
check_openmpi_git

ompi_info