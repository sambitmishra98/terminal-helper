#!/usr/bin/env bash
get_gcc_pkg(){
    setup_base
    export_all_versions
    mkdir -p $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER
    echo "GCC $BUILD_GCC_VER downloaded at $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER"
    wget https://ftp.mpi-inf.mpg.de/mirrors/gnu/mirror/gcc.gnu.org/pub/gcc/releases/gcc-$BUILD_GCC_VER/gcc-$BUILD_GCC_VER.tar.xz -P $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER
    tar -xf $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER/gcc-$BUILD_GCC_VER.tar.xz -C $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER
    rm $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER/gcc-$BUILD_GCC_VER.tar.xz
}

setup_gcc_pkg(){
    setup_base
    export_all_versions
    cd $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER/gcc-$BUILD_GCC_VER
    contrib/download_prerequisites
    mkdir -p $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER/build
    cd       $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER/build/
    echo "Configuring GCC from: $PKG_DOWNLOAD/gcc/$BUILD_GCC_VER/build/"
    CMD="../gcc-$BUILD_GCC_VER/configure --prefix=$PKG_LOCAL/gcc/$BUILD_GCC_VER --enable-languages=c,c++,fortran --disable-multilib"
    echo $CMD
    eval $CMD
    make clean
    make -j 12
    make install
}
