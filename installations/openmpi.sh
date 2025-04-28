


get_openmpi_pkg(){
    setup_base
    export_all_versions
    mkdir -p $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER
    cd $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER
    echo "Downloading OpenMPI in $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER"
    wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-$BUILD_OPENMPI_VER.tar.gz -P $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER
    tar -xf openmpi-$BUILD_OPENMPI_VER.tar.gz
    rm openmpi-$BUILD_OPENMPI_VER.tar.gz
}

setup_openmpi_pkg(){
    setup_base
    export_all_versions
    cd $PKG_DOWNLOAD/openmpi/$BUILD_OPENMPI_VER/openmpi-$BUILD_OPENMPI_VER

    # CUDA compute node
    CMD="./configure --prefix=$PKG_LOCAL/openmpi-cuda/$BUILD_OPENMPI_VER --enable-shared --enable-heterogeneous --with-cuda=/usr/local/cuda-12.2/ --with-ucx=$PKG_LOCAL/ucx-cuda/$BUILD_UCX_VER --with-pmi --with-slurm" ; echo $CMD

    # Open MPI configuration:
    # -----------------------
    # Version: 4.1.6
    # Build MPI C bindings: yes
    # Build MPI C++ bindings (deprecated): no
    # Build MPI Fortran bindings: mpif.h, use mpi, use mpi_f08
    # MPI Build Java bindings (experimental): no
    # Build Open SHMEM support: yes
    # Debug build: no
    # Platform file: (none)
    # 
    # Miscellaneous
    # -----------------------
    # CUDA support: yes
    # HWLOC support: internal
    # Libevent support: internal
    # Open UCC: no
    # PMIx support: Internal
    #  
    # Transports
    # -----------------------
    # Cisco usNIC: no
    # Cray uGNI (Gemini/Aries): no
    # Intel Omnipath (PSM2): no
    # Intel TrueScale (PSM): no
    # Mellanox MXM: no
    # Open UCX: yes
    # OpenFabrics OFI Libfabric: no
    # OpenFabrics Verbs: yes
    # Portals4: no
    # Shared memory/copy in+copy out: yes
    # Shared memory/Linux CMA: yes
    # Shared memory/Linux KNEM: no
    # Shared memory/XPMEM: no
    # TCP: yes
    #  
    # Resource Managers
    # -----------------------
    # Cray Alps: no
    # Grid Engine: no
    # LSF: no
    # Moab: no
    # Slurm: yes
    # ssh/rsh: yes
    # Torque: no
    #  
    # OMPIO File Systems
    # -----------------------
    # DDN Infinite Memory Engine: no
    # Generic Unix FS: yes
    # IBM Spectrum Scale/GPFS: no
    # Lustre: no
    # PVFS2/OrangeFS: no


    # ROCM compute node
    CMD="./configure --prefix=$PKG_LOCAL/openmpi/$BUILD_OPENMPI_VER --enable-shared --enable-heterogeneous --with-rocm=/opt/rocm-6.0.0 --with-ucx=$PKG_LOCAL/ucx-rocm/$BUILD_UCX_VER --with-pmi --with-slurm" ; echo $CMD

    eval $CMD
    make clean ; make -j 32
    make install
}

