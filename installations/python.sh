
get_python_pkg(){
    setup_base ; export_all_versions
    mkdir -p $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER
    echo "Python version $BUILD_PYTHON_VER downloaded at $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER"
    wget https://www.python.org/ftp/python/$BUILD_PYTHON_VER/Python-$BUILD_PYTHON_VER.tgz -P $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER
    tar -xf $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER/Python-$BUILD_PYTHON_VER.tgz -C $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER
    rm $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER/Python-$BUILD_PYTHON_VER.tgz
}

setup_python_pkg(){
    setup_base ; export_all_versions
    cd $PKG_DOWNLOAD/python/$BUILD_PYTHON_VER/Python-$BUILD_PYTHON_VER
    #CMD="./configure --prefix=$PKG_LOCAL/foss2022b/python/$BUILD_PYTHON_VER --enable-shared --with-openssl=$EBROOTOPENSSL --enable-optimizations"
    CMD="./configure --prefix=$PKG_LOCAL/foss2022b/python/$BUILD_PYTHON_VER --enable-shared --with-openssl=$PKG_LOCAL/openssl/$BUILD_OPENSSL_VER --enable-optimizations" ; echo $CMD
    #CMD="./configure --prefix=$PKG_LOCAL/python/login2/$BUILD_PYTHON_VER --enable-shared --with-openssl=$EBROOTOPENSSL  --enable-optimizations"
    eval $CMD
    make clean ; make -j 24
    make install
}