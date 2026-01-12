source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh

add_installation_to_path rocm-6.4.1/ ""      /opt/
add_installation_to_path cuda-12.5/ ""      /usr/local/

add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

source $SAMBITMISHRA98/terminal-helper/lib/installers/installations/ucx-git.sh

export UCX_VER="master"
# clone_ucx_git $UCX_VER  # clones UCX git repo into $EXTRACTS
# autogen_ucx_git          # generates ./configure
# configure_mixed_ucx_git        # picks up CUDA + verbs
# make_install_mixed_ucx_git          # copies into $INSTALLS

add_installation_to_path ucx-mixed "$UCX_VER" "$INSTALLS"
#check_ucx_git            # prints ucx_info summary
