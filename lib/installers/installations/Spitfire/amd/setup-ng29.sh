

source $SAMBITMISHRA98/terminal-helper/lib/common/add_installation.sh

# BASICS
add_installation_to_path rocm-6.4.1 ""      /opt/
add_installation_to_path gcc  12.3.0  $SCRATCH/.local-spitfire/pkg/

# MPI
add_installation_to_path ucx-rocm master "$INSTALLS"
add_installation_to_path ompi-rocm main "$INSTALLS"

# PYTHON
add_installation_to_path libffi  3.4.8   $INSTALLS
add_installation_to_path openssl 1.1.1w  $INSTALLS
add_installation_to_path python  3.13.3  $INSTALLS

# ASCENT
export ASCENT_REF="develop_rocm_ucx-master_ompi-main"
export ASCENT_INSTALLATION_LOCATION="${INSTALLS}/ascent/${ASCENT_REF}/install/"
add_installation_to_path "conduit-v0.9.4" "" "${ASCENT_INSTALLATION_LOCATION}"
add_installation_to_path "vtk-m-v2.3.0"   "" "${ASCENT_INSTALLATION_LOCATION}"
export PYFR_ASCENT_MPI_LIBRARY_PATH="${ASCENT_INSTALLATION_LOCATION}/ascent-checkout/lib/libascent_mpi.so"

# OPENMP
export  PYFR_XSMM_LIBRARY_PATH=$SCRATCH/.local-spitfire/git/libxsmm/libxsmm/lib/libxsmm.so

# METIS
export PYFR_METIS_LIBRARY_PATH=$SCRATCH/.local-spitfire/git/metis/lib/libmetis.so

# RTREE
add_installation_to_path libspacialindex "" $INSTALLS

# ------------------------------------------------------------------------------    
