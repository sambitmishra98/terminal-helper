
get_openssl_pkg(){
    setup_base ; export_all_versions
    mkdir -p $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER
    echo "OpenSSL version $BUILD_OPENSSL_VER downloaded at $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER"
    wget https://www.openssl.org/source/openssl-$BUILD_OPENSSL_VER.tar.gz -P $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER
    tar -xf $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER/openssl-$BUILD_OPENSSL_VER.tar.gz -C $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER
    rm $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER/openssl-$BUILD_OPENSSL_VER.tar.gz
}

setup_openssl_pkg(){
    setup_base ; export_all_versions
    cd $PKG_DOWNLOAD/openssl/$BUILD_OPENSSL_VER/openssl-$BUILD_OPENSSL_VER
    CMD="./config --prefix=$PKG_LOCAL/openssl/$BUILD_OPENSSL_VER" ; echo $CMD
    eval $CMD
    make clean ; make -j 32
    make install
}