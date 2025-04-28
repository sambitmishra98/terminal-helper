get_libffi_pkg(){
    setup_base ; export_all_versions
    mkdir -p $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER
    echo "libffi version $BUILD_LIBFFI_VER downloaded at $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER"
    wget https://github.com/libffi/libffi/releases/download/v$BUILD_LIBFFI_VER/libffi-$BUILD_LIBFFI_VER.tar.gz -P $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER
    tar -xvf $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER/libffi-$BUILD_LIBFFI_VER.tar.gz -C $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER
    rm $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER/libffi-$BUILD_LIBFFI_VER.tar.gz
}

setup_libffi_pkg(){
    setup_base ; export_all_versions
    cd $PKG_DOWNLOAD/libffi/$BUILD_LIBFFI_VER/libffi-$BUILD_LIBFFI_VER
    CMD="./configure --prefix=$PKG_LOCAL/libffi/$BUILD_LIBFFI_VER" ; echo $CMD
    eval $CMD
    make clean ; make -j 32
    make install
}
