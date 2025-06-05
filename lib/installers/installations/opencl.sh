#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Kronos OpenCL headers and ICD loader
# ------------------------------------------------------------------------------

get_opencl_git() {
    setup_base
    export_all_versions
    echo "Downloading OpenCL Headers"    ; mkdir -p $GIT_DOWNLOAD/OpenCL-Headers    
    git clone https://github.com/KhronosGroup/OpenCL-Headers.git    $GIT_DOWNLOAD/OpenCL-Headers
    echo "Downloading OpenCL ICD Loader" ; mkdir -p $GIT_DOWNLOAD/OpenCL-ICD-Loader 
    git clone https://github.com/KhronosGroup/OpenCL-ICD-Loader.git $GIT_DOWNLOAD/OpenCL-ICD-Loader
}

setup_opencl_git() {
    setup_base
    export_all_versions

    cd $GIT_DOWNLOAD

    mkdir -p $GIT_LOCAL/opencl/OpenCL-Headers
    mkdir -p $GIT_LOCAL/opencl/OpenCL-ICD-Loader ; 

    #cmake -D CMAKE_INSTALL_PREFIX=$GIT_LOCAL/opencl/OpenCL-Headers -S $GIT_DOWNLOAD/OpenCL-Headers -B $GIT_DOWNLOAD/OpenCL-Headers/build
    #cmake --build $GIT_DOWNLOAD/OpenCL-Headers/build --target install

    cmake -D CMAKE_INSTALL_PREFIX=./OpenCL-Headers/install -S ./OpenCL-Headers -B ./OpenCL-Headers/build 
    cmake --build ./OpenCL-Headers/build --target install

    #cmake -D CMAKE_PREFIX_PATH=$GIT_LOCAL/opencl/OpenCL-Headers -D CMAKE_INSTALL_PREFIX=$GIT_LOCAL/opencl/OpenCL-ICD-Loader -S $GIT_DOWNLOAD/OpenCL-ICD-Loader -B $GIT_DOWNLOAD/OpenCL-ICD-Loader/build
    #cmake --build $GIT_DOWNLOAD/OpenCL-ICD-Loader/build --target install

    cmake -D CMAKE_PREFIX_PATH=/mnt/share/sambit98/.downloads/git/OpenCL-Headers/install -D CMAKE_INSTALL_PREFIX=./OpenCL-ICD-Loader/install -S ./OpenCL-ICD-Loader -B ./OpenCL-ICD-Loader/build 
    cmake --build ./OpenCL-ICD-Loader/build --target install
}
