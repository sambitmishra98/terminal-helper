#!/usr/bin/env bash
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 1. Which branch/tag of Ascent to install?
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
set_ascent_version() {
    # You can change this to a release tag (e.g. "v0.9.3") if desired
    ASCENT_VER="develop"
    echo "[INFO] Building Ascent from branch/tag: ${ASCENT_VER}"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 2. Clone the Ascent repository (with submodules)
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
download_ascent() {
    local dest="${DOWNLOADS}/ascent/${ASCENT_VER}"
    echo "[INFO] Cloning Ascent into $dest"
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    git clone --recursive --branch "$ASCENT_VER" https://github.com/Alpine-DAV/ascent.git "$dest"
    echo "[OK] Ascent source ready"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 3. Load modules / ensure dependencies
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
prepare_environment() {
    echo "[INFO] Checking for CMake..."
    if ! command -v cmake &>/dev/null; then
        echo "[ERROR] cmake not found in PATH; please load or install CMake ≥3.21"
        return 1
    fi
    echo "[OK] CMake found: $(cmake --version | head -n1)"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 4. Build (and install) Ascent with MPI support
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
build_ascent() {
    # If The required UCX and OMPI are not found, error out
    if [ -z "${UCX_VER}" ] || [ -z "${OMPI_VER}" ]; then
        echo "[ERROR] UCX or OpenMPI version not set!"
        return 1
    fi

    local src="${DOWNLOADS}/ascent/${ASCENT_VER}"
    local prefix="${INSTALLS}/ascent/${ASCENT_VER}_cuda_ucx-${UCX_VER}_ompi-${OMPI_VER}"
    local log="$src/build_ascent.log"

    echo "[INFO] Creating install prefix at $prefix"
    mkdir -p "$prefix"

    echo "[INFO] Building Ascent (MPI enabled)…"
    cd "$src/scripts/build_ascent"

    # The build_ascent.sh script will pull in dependencies (Conduit, VTK-m, etc.)
    # and install everything under $prefix
    env prefix="$prefix" enable_mpi=ON ./build_ascent.sh 2>&1 | tee "$log"

    echo "[OK] Ascent built and installed to $prefix"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 5. Verify the Ascent MPI library and tell PyFR where it is
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
check_ascent() {
    local prefix="${INSTALLS:-$HOME/installs}/ascent/${ASCENT_VER}"
    local lib="$prefix/lib/libascent_mpi.so"

    echo "[INFO] Verifying Ascent MPI library at $lib"
    if [ -f "$lib" ]; then
        echo "[OK] Found libascent_mpi.so"
        echo
        echo "👉 To use Ascent in PyFR, set:"
        echo "   export PYFR_ASCENT_MPI_LIBRARY_PATH=$lib"
    else
        echo "[ERROR] libascent_mpi.so not found; check build log"
        return 1
    fi
}

#— Add Ascent and its dependencies to your environment —#
# export ASCENT_VER="develop"
# add_installation_to_path "conduit-vx.x.x" "" "${INSTALLS}/ascent/${ASCENT_VER}/scripts/build_ascent/install/"
# add_installation_to_path "vtk-m-vx.x.x"   "" "${INSTALLS}/ascent/${ASCENT_VER}/scripts/build_ascent/install/"
# export PYFR_ASCENT_MPI_LIBRARY_PATH="${ASCENT_INSTALLATION_LOCATION}/lib/libascent_mpi.so"
