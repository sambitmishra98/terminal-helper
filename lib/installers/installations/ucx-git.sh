###############################################################################
# clone_ucx_git : shallow-clone a given UCX tag/branch and keep directory
#                 layout identical to the tar-ball workflow
#
#   • Usage:
#         clone_ucx_git           # clones latest stable (v1.18.1)
#         clone_ucx_git v1.17.0   # clones a specific tag
#         clone_ucx_git master    # tracks bleeding-edge
#
#   • Expects the usual globals to be pre-defined in your environment:
#         $DOWNLOADS, $EXTRACTS, $INSTALLS
#
#   • Produces:
#         $DOWNLOADS/ucx/$UCX_VER/clone.log
#         $EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER/   (git working tree)
###############################################################################
clone_ucx_git() {
    # -------- 1. decide tag / branch ----------------------------------------
    local tag="${1:-v1.18.1}"                       # default to latest stable
    export UCX_VER="${tag#v}"                       # strip leading “v” if any
    echo "[INFO] Cloning UCX $tag  (=> UCX_VER=$UCX_VER)"

    # -------- 2. path scaffolding -------------------------------------------
    local dl_dir="${DOWNLOADS}/ucx/${UCX_VER}"
    local src_dir="${EXTRACTS}/ucx/${UCX_VER}/ucx-${UCX_VER}"
    local log="${dl_dir}/clone.log"
    mkdir -p "${dl_dir}"
    mkdir -p "$(dirname "${src_dir}")"

    # -------- 3. actual clone ----------------------------------------------
    if [ -d "${src_dir}/.git" ]; then
        echo "[WARN] ${src_dir} already exists – skipping fresh clone"
    else
        git clone --depth 1 --branch "${tag}" https://github.com/openucx/ucx.git "${src_dir}" 2>&1 | tee "${log}"
    fi

    # -------- 4. validation -------------------------------------------------
    if [ -d "${src_dir}/src/ucs" ]; then
        echo "[OK] UCX git checkout complete → ${src_dir}"
    else
        echo "[ERROR] UCX clone failed – inspect ${log}"
        return 1
    fi
}

###############################################################################
# 1. autogen_ucx_git : run ./autogen.sh (git checkout only)
###############################################################################
autogen_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-autogen.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Running autogen for UCX $UCX_VER ..."
    ./autogen.sh 2>&1 | tee "$log"

    grep -q "Generating configure" "$log" \
        && echo "[OK] autogen completed" \
        || { echo "[ERROR] autogen failed – see $log"; return 1; }
}

###############################################################################
# 2. configure_ucx_git : ./contrib/configure-release with CUDA & verbs
###############################################################################
configure_cuda_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-configure.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Configuring UCX $UCX_VER for CUDA & HDR-IB ..."
    ./contrib/configure-release \
        --prefix="$INSTALLS/ucx-cuda/$UCX_VER" \
        --enable-shared                \
        --enable-cma                   \
        --enable-mt                    \
        --with-cuda=/usr/local/cuda    \
        --with-verbs                   \
        --with-rc --with-dc            \
        --with-mlx5-dv                 \
        2>&1 | tee "$log"

    grep -E "CUDA.*yes" "$log" >/dev/null && \
    grep -E "mlx5.*yes" "$log" >/dev/null && \
        echo "[OK] Configure found CUDA + MLX5 support" \
      || echo "[WARN] Check $log – expected CUDA/MLX5 flags not detected"
}

configure_rocm_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-configure.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Configuring UCX $UCX_VER for ROCM & HDR-IB ..."
    ./contrib/configure-release \
        --prefix="$INSTALLS/ucx-rocm/$UCX_VER" \
        --enable-shared                \
        --enable-cma                   \
        --enable-mt                    \
        --with-rocm=/opt/rocm           \
        --with-verbs                   \
        --with-rc --with-dc            \
        --with-mlx5-dv                 \
        2>&1 | tee "$log"

}


configure_mixed_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local pre="$INSTALLS/ucx-mixed/$UCX_VER"
    local log="$src/build-configure.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Configuring UCX $UCX_VER for CUDA *and* ROCm ..."
    ./contrib/configure-release \
        --prefix="$pre"               \
        --enable-shared               \
        --enable-mt                   \
        --with-cuda=/usr/local/cuda   \
        --with-rocm=/opt/rocm         \
        --with-verbs                  \
        --with-rc --with-dc           \
        --with-mlx5dv --disable-debug \
        2>&1 | tee "$log"

    # quick sanity check: did both GPUs register?
    grep -E "CUDA.*yes"  "$log" >/dev/null && \
    grep -E "ROCm.*yes"  "$log" >/dev/null && \
        echo "[OK] Configure found CUDA *and* ROCm support" \
      || { echo "[WARN] One of the GPU back-ends is missing – inspect $log"; }
}





###############################################################################
# 3. make_ucx_git : compile with full parallelism
###############################################################################
make_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-make.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Building UCX ..."
    make clean        2>&1
    make -j$(nproc) 2>&1 | tee "$log"

    grep -q "error:" "$log" \
        && { echo "[ERROR] Compilation errors – see $log"; return 1; } \
        || echo "[OK] Build completed without errors"
}

###############################################################################
# 4. install_ucx_git & check_ucx_git : install then sanity-check
###############################################################################
install_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-install.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Installing UCX to $INSTALLS/ucx-cuda/$UCX_VER ..."
    make install 2>&1 | tee "$log"

    [ -f "$INSTALLS/ucx-cuda/$UCX_VER/lib/libuct.so" ] \
        && echo "[OK] Installation succeeded" \
        || { echo "[ERROR] libuct.so missing – see $log"; return 1; }
}

install_rocm_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-install.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Installing UCX to $INSTALLS/ucx-rocm/$UCX_VER ..."
    make install 2>&1 | tee "$log"

    [ -f "$INSTALLS/ucx-rocm/$UCX_VER/lib/libuct.so" ] \
        && echo "[OK] Installation succeeded" \
        || { echo "[ERROR] libuct.so missing – see $log"; return 1; }
}

###############################################################################
# install_mixed_ucx_git : make && make install for the mixed build
###############################################################################
make_install_mixed_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local pre="$INSTALLS/ucx-mixed/$UCX_VER"
    local log="$src/build-install.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }

    echo "[INFO] Building UCX (mixed) ..."
    make clean        2>&1
    make -j$(nproc) 2>&1 | tee "$log"

    echo "[INFO] Installing UCX to $pre ..."
    make install 2>&1 | tee -a "$log"

    # post-install validation: list GPU transports
    if "$pre/bin/ucx_info" -d | grep -qE "(cuda|rocm)_ipc"; then
        echo "[OK] Mixed UCX install succeeded (CUDA + ROCm providers present)"
    else
        echo "[ERROR] ucx_info did not list both GPU providers – check $log"
        return 1
    fi
}


check_ucx_git() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-check.log"

    echo "[INFO] Running ucx_info sanity checks ..."
    {
        echo "=== Build flags ==="
        ucx_info -b
        echo
        echo "=== Devices / Transports ==="
        ucx_info -d
        echo
        echo "=== Full config ==="
        ucx_info -c -a
    } 2>&1 | tee "$log"

    echo "[OK] UCX capability check complete – see $log"
}
