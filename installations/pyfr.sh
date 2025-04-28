setup_pyfr_venv_prerequisites(){
    setup_base
    export_all_versions

    export VENV_rocm="venv-pyfr-rocm-ucx-ompi416"

    mkdir -p $VENV_LOCAL/$VENV_rocm
    python3.12 -m venv $VENV_LOCAL/$VENV_rocm
    source $VENV_LOCAL/$VENV_rocm/bin/activate
    pip install --upgrade pip
    pip install --no-cache-dir mpi4py   
    # Pause here, above line is problematic
    pip install --no-cache-dir pyfr
    pip install --no-cache-dir setuptools rtree
    pip uninstall -y pyfr
}

setup_pyfr_venv_base(){
    setup_base
    export_all_versions
    git clone https://github.com/sambitmishra98/PyFR.git $GIT_LOCAL/Github_PyFR/$VENV_rocm
    cd $GIT_LOCAL/Github_PyFR/$VENV_rocm
    python3 setup.py develop
    git clone https://github.com/PyFR/PyFR-Test-Cases.git $GIT_LOCAL/Github_PyFR-Test-Cases/$VENV_rocm
    cd $GIT_LOCAL/Github_PyFR-Test-Cases/$VENV_rocm/2d-euler-vortex
    pyfr import euler-vortex.msh euler-vortex.pyfrm

    pyfr run -b openmp euler-vortex.pyfrm euler-vortex.ini

    pyfr -p run -b hip euler-vortex.pyfrm euler-vortex.ini

    pyfr partition 2 euler-vortex.pyfrm .
    mpirun -n 2 pyfr run -b openmp euler-vortex.pyfrm euler-vortex.ini

    pyfr partition 1 euler-vortex.pyfrm .
    pyfr run -b cuda euler-vortex.pyfrm euler-vortex.ini
    mpirun -n 2 pyfr run -b cuda euler-vortex.pyfrm euler-vortex.ini
}

setup_pyfr_venv_benchmarking(){
    add_all_paths
    cd $GIT_LOCAL/Github_PyFR/$VENV_rocm
    git checkout benchmark
    python3 setup.py develop
    pip3 install pandas matplotlib seaborn
}

