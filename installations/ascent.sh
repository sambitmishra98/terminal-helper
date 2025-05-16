#!/usr/bin/env bash
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 1. Which branch/tag of Ascent to install?
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
set_ascent_version() {
    # You can change this to a release tag (e.g. "v0.9.3") if desired
    ASCENT_REF="develop"
    echo "[INFO] Building Ascent from branch/tag: ${ASCENT_REF}"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 2. Clone the Ascent repository (with submodules)
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
download_ascent() {
    local dest="${DOWNLOADS:-$HOME/downloads}/ascent/${ASCENT_REF}"
    echo "[INFO] Cloning Ascent into $dest"
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    git clone --recursive --branch "$ASCENT_REF" https://github.com/Alpine-DAV/ascent.git "$dest"
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
    local src="${DOWNLOADS:-$HOME/downloads}/ascent/${ASCENT_REF}"
    local prefix="${INSTALLS:-$HOME/installs}/ascent/${ASCENT_REF}"
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
    local prefix="${INSTALLS:-$HOME/installs}/ascent/${ASCENT_REF}"
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

# ### Add Ascent and some of its dependencies to path
# ```
# export ASCENT_INSTALLATION_LOCATION=/scratch/user/u.sm121949/.downloads/git/ascent
# add_installation_to_path "conduit-v0.9.1" "" "$ASCENT_INSTALLATION_LOCATION/scripts/build_ascent/install/"
# add_installation_to_path "vtk-m-v2.1.0" "" "$ASCENT_INSTALLATION_LOCATION/scripts/build_ascent/install/"
# 
# export PYFR_ASCENT_MPI_LIBRARY_PATH=$ASCENT_INSTALLATION_LOCATION/scripts/build_ascent/install/ascent-develop/lib/libascent_mpi.so
# ```


#— Add Ascent and its dependencies to your environment —#
# export ASCENT_REF="develop"
# add_installation_to_path "conduit-vx.x.x" "" "${INSTALLS}/ascent/${ASCENT_REF}/scripts/build_ascent/install/"
# add_installation_to_path "vtk-m-vx.x.x"   "" "${INSTALLS}/ascent/${ASCENT_REF}/scripts/build_ascent/install/"
# export PYFR_ASCENT_MPI_LIBRARY_PATH="${ASCENT_INSTALLATION_LOCATION}/lib/libascent_mpi.so"
