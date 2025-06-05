#!/usr/bin/env bash
set_ucx_version() {
    export UCX_VER="1.18.0"
    echo "[INFO] Setting UCX version to $UCX_VER"
}

download_ucx() {
    local log="$DOWNLOADS/ucx/$UCX_VER/download.log"
    mkdir -p "$DOWNLOADS/ucx/$UCX_VER"
    echo "[INFO] Downloading UCX v$UCX_VER to $DOWNLOADS/ucx/$UCX_VER"
    wget "https://github.com/openucx/ucx/releases/download/v$UCX_VER/ucx-$UCX_VER.tar.gz" \
         -O "$DOWNLOADS/ucx/$UCX_VER/ucx-$UCX_VER.tar.gz" \
         2>&1 | tee "$log"

    if grep -q "ERROR" "$log"; then
        echo "[ERROR] Download failed; see $log"
        return 1
    else
        echo "[OK] Download completed successfully"
    fi
}

extract_ucx() {
    local log="$DOWNLOADS/ucx/$UCX_VER/extract.log"
    echo "[INFO] Extracting UCX tarball to $EXTRACTS/ucx/$UCX_VER/"
    mkdir -p "$EXTRACTS/ucx/$UCX_VER"
    tar -xf "$DOWNLOADS/ucx/$UCX_VER/ucx-$UCX_VER.tar.gz" \
        -C "$EXTRACTS/ucx/$UCX_VER" 2>&1 | tee "$log"

    if [ ! -d "$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER" ]; then
        echo "[ERROR] Extraction failed; directory missing"
        return 1
    else
        echo "[OK] Extraction succeeded"
    fi
}

configure_ucx() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local build_log="$src/build-configure.log"

    cd "$src"

    echo "[INFO] Configuring UCX..."
    ./configure \
        --prefix="$INSTALLS/ucx-cuda/$UCX_VER" \
        --enable-shared \
        --with-cuda=/usr/local/cuda/ \
        --enable-devel-headers \
        --enable-cma \
        --enable-mt \
        --with-rc \
        --with-dc \
        --with-ib-hw-tm \
        --with-mlx5-dv \
        --with-verbs \
        --with-iodemo-cuda \
        2>&1 | tee "$build_log"

    # Validate configure
    grep -E "RDMA|gpudirect|CUDA" "$build_log" >/dev/null \
        && echo "[OK] Configure: RDMA/GPUDIRECT/CUDA flags present" \
        || echo "[WARN] Check $build_log: missing expected RDMA/GPUDIRECT flags"

}

make_ucx() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local make_log="$src/build-make.log"

    cd "$src"

    echo "[INFO] Building UCX (make)..."
    make clean 2>&1
    make -j24 2>&1 | tee "$make_log"

    # Validate build
    if grep -q "error:" "$make_log"; then
        echo "[ERROR] Build errors detected; see $make_log"
        return 1
    else
        echo "[OK] Make completed without errors"
    fi

}

install_ucx() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local install_log="$src/build-install.log"

    cd "$src"

    echo "[INFO] Installing UCX (make install)..."
    make install 2>&1 | tee "$install_log"

    # Validate install
    if [ -f "$INSTALLS/ucx-cuda/$UCX_VER/lib/libuct.so" ]; then
        echo "[OK] Installation succeeded and libraries are present"
    else
        echo "[ERROR] Installation failed; missing libuct.so in prefix"
        return 1
    fi

}

check_ucx() {
    local src="$EXTRACTS/ucx/$UCX_VER/ucx-$UCX_VER"
    local log="$src/build-check.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src" | tee "$log"; return 1; }

    echo "=== UCX Build Configuration ===" | tee "$log"
    ucx_info -b 2>&1 | tee -a "$log"                      # show compile-time flags :contentReference[oaicite:0]{index=0}

    echo; echo "=== UCX Devices & Transports ===" | tee -a "$log"
    ucx_info -d 2>&1 | tee -a "$log"                      # list enabled transports (rc,dc,rdmacm,cuda,…) :contentReference[oaicite:1]{index=1}

    echo; echo "=== UCX Full Configuration (hidden too) ===" | tee -a "$log"
    ucx_info -c -a 2>&1 | tee -a "$log"                   # all runtime config options :contentReference[oaicite:2]{index=2}

    echo; echo "=== UCX Default & Environment Variables ===" | tee -a "$log"
    ucx_info -f 2>&1 | tee -a "$log"                      # full decorated output: default param values :contentReference[oaicite:3]{index=3}

    echo; echo "=== UCX System Information ===" | tee -a "$log"
    ucx_info -s 2>&1 | tee -a "$log"                      # OS, CPU, memory, pci info :contentReference[oaicite:4]{index=4}

    echo; echo "=== GPU/RDMA Hardware Check ===" | tee -a "$log"
    ibdev2netdev 2>&1 | tee -a "$log"                     # ensure IB ports are up :contentReference[oaicite:5]{index=5}
    echo                                             | tee -a "$log"
    ucx_info -p -u t 2>&1 | tee -a "$log"                  # show what UCX sees on each device :contentReference[oaicite:6]{index=6}

    echo; echo "[OK] UCX capability check complete; see $log" | tee -a "$log"
}
