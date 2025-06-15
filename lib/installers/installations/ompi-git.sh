###############################################################################
# clone_openmpi_git : shallow-clone (+submodules) Open MPI tag / branch
#
#   • Usage examples
#         clone_openmpi_git          # latest v5.x (v5.0.7 today)
#         clone_openmpi_git v5.0.6   # fixed tag
#         clone_openmpi_git master   # bleeding-edge
###############################################################################
clone_openmpi_git() {
    local tag="${1:-v5.0.7}"
    export OMPI_VER="${tag#v}"
    echo "[INFO] Cloning Open-MPI $tag (=> OMPI_VER=$OMPI_VER)"

    local dl_dir="${DOWNLOADS}/openmpi/${OMPI_VER}"
    local src_dir="${EXTRACTS}/openmpi/${OMPI_VER}/openmpi-${OMPI_VER}"
    local log="${dl_dir}/clone.log"
    mkdir -p "${dl_dir}" "$(dirname "${src_dir}")"

    if [ -d "${src_dir}/.git" ]; then
        echo "[WARN] ${src_dir} already exists – skipping fresh clone"
    else
        git clone --recursive --branch "${tag}" \
                  https://github.com/open-mpi/ompi.git "${src_dir}" \
                  2>&1 | tee "${log}"
    fi

    [ -d "${src_dir}/ompi" ] || { echo "[ERROR] clone failed – see ${log}"; return 1; }
    export OMPI_HASH="$(git -C "${src_dir}" rev-parse --short HEAD)"
    echo "[OK] checkout ${OMPI_HASH} → ${src_dir}"
}


###############################################################################
# autogen_openmpi_git : generate ./configure only if missing
###############################################################################
autogen_openmpi_git() {
    local src="$EXTRACTS/openmpi/$OMPI_VER/openmpi-$OMPI_VER"
    local log="$src/build-autogen.log"
    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    [[ -x configure ]] && { echo "[INFO] configure present – skip autogen"; return 0; }

    echo "[INFO] Running autogen ..."
    ./autogen.pl 2>&1 | tee "$log"
    grep -q "Generating configure" "$log" && echo "[OK] autogen done" \
        || { echo "[ERROR] autogen failed – see $log"; return 1; }
}


###############################################################################
# configure_openmpi_git : CUDA-aware + UCX + MCA-DSO + Sphinx docs
###############################################################################
configure_openmpi_git() {
    local src="$EXTRACTS/openmpi/$OMPI_VER/openmpi-$OMPI_VER"
    local log="$src/build-configure.log"
    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    ensure_docs_venv                        # ← new line

    echo "[INFO] Configuring Open-MPI $OMPI_VER (UCX=$UCX_VER, MCA-DSO, docs) ..."
    ./configure \
        --prefix="$INSTALLS/ompi-cuda/$OMPI_VER" \
        --with-ucx="$INSTALLS/ucx-cuda/$UCX_VER" \
        --with-cuda=/usr/local/cuda \
        --enable-mca-dso=all \
        --enable-sphinx \
        --with-sphinx-build="$SPHINX_BUILD" \
        --enable-make-install-docs \
        --enable-shared \
        2>&1 | tee "$log"

    grep -q "UCX support.*yes" "$log" && grep -q "CUDA.*yes" "$log" \
        && echo "[OK] configure saw CUDA + UCX" \
        || echo "[WARN] CUDA/UCX missing – see $log"
}

###############################################################################
# make_openmpi_git : parallel build (tunable)
###############################################################################
make_openmpi_git() {
    local src="$EXTRACTS/openmpi/$OMPI_VER/openmpi-$OMPI_VER"
    local log="$src/build-make.log"
    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    ensure_docs_venv                        # ← new line

    local jobs="${OMPI_MAKE_JOBS:-$(nproc)}"
    echo "[INFO] Building with -j${jobs} ..."
    make -j"${jobs}" 2>&1 | tee "$log"
    grep -q "error:" "$log" \
        && { echo "[ERROR] Build errors – see $log"; return 1; } \
        || echo "[OK] Build finished"
}

###############################################################################
# ensure_docs_venv : make sure a Sphinx venv is present and activated
#   • Creates $VENVS/openmpi-docs-$OMPI_VER on first call
#   • Installs exactly the Python modules listed in docs/requirements.txt
#   • Exports SPHINX_BUILD so configure / make can find it
###############################################################################
ensure_docs_venv() {
    local src="$EXTRACTS/openmpi/$OMPI_VER/openmpi-$OMPI_VER"   # needs a checkout
    export OMPI_DOCS_VENV="$src/openmpi-docs-$OMPI_VER"

    if [ ! -d "$OMPI_DOCS_VENV" ]; then
        echo "[INFO] [docs] venv missing – creating → $OMPI_DOCS_VENV"
        python3 -m venv "$OMPI_DOCS_VENV"                       || return 1
        source "$OMPI_DOCS_VENV/bin/activate"
        pip install -q --upgrade pip                            # keep pip current
        pip install -q -r "$src/docs/requirements.txt"          # official list :contentReference[oaicite:2]{index=2}
    else
        source "$OMPI_DOCS_VENV/bin/activate"
        echo "[INFO] [docs] using existing venv $OMPI_DOCS_VENV"
    fi

    export SPHINX_BUILD="$OMPI_DOCS_VENV/bin/sphinx-build"      # used by configure
}


###############################################################################
# install_openmpi_git & check_openmpi_git : unchanged except new docs helper
###############################################################################
install_openmpi_git() {
    local src="$EXTRACTS/openmpi/$OMPI_VER/openmpi-$OMPI_VER"
    local log="$src/build-install.log"
    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    ensure_docs_venv                        # ← new line

    echo "[INFO] Installing ..."
    make install 2>&1 | tee "$log"
    [ -x "$INSTALLS/ompi-cuda/$OMPI_VER/bin/mpicc" ] && echo "[OK] install done" \
        || { echo "[ERROR] mpicc missing – see $log"; return 1; }

}

check_openmpi_git() {
    local log="$EXTRACTS/openmpi/$OMPI_VER/openmpi-$OMPI_VER/build-check.log"
    echo "[INFO] Running ompi_info ..."
    { ompi_info --parsable --all | head -20; echo; mpirun --version; } 2>&1 | tee "$log"
    echo "[OK] sanity check complete – see $log"
}