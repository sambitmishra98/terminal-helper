get_ucx_pkg(){     
    setup_base ; export_all_versions     
    mkdir -p $PKG_DOWNLOAD/ucx/$BUILD_UCX_VER ; cd $PKG_DOWNLOAD/ucx/$BUILD_UCX_VER
    echo "Downloading UCX in $PKG_DOWNLOAD/ucx/$BUILD_UCX_VER";
    wget https://github.com/openucx/ucx/releases/download/v$BUILD_UCX_VER/ucx-$BUILD_UCX_VER.tar.gz -P $PKG_DOWNLOAD/ucx/$BUILD_UCX_VER
    tar -xf ucx-$BUILD_UCX_VER.tar.gz ; rm ucx-$BUILD_UCX_VER.tar.gz
}

setup_ucx_pkg(){     
    setup_base ; export_all_versions     
    cd $PKG_DOWNLOAD/ucx/$BUILD_UCX_VER/ucx-$BUILD_UCX_VER;     

    # CUDA compute node
    CMD="./configure --prefix=$PKG_LOCAL/ucx-cuda/$BUILD_UCX_VER --enable-shared --with-cuda=/usr/local/cuda-12.2/ --enable-devel-headers --enable-cma --enable-mt --with-rc --with-dc --with-ib-hw-tm --with-mlx5-dv --with-verbs --with-iodemo-cuda" ; echo $CMD
    #ROCM compute node
    CMD="./configure --prefix=$PKG_LOCAL/ucx-rocm/$BUILD_UCX_VER --enable-shared --with-rocm=/opt/rocm-6.0.0/ --enable-devel-headers --enable-cma --enable-mt --with-rc --with-dc --with-ib-hw-tm --with-mlx5-dv --with-verbs" ; echo $CMD

    eval $CMD
    make clean ; make -j 24;     
    make install; 
}
