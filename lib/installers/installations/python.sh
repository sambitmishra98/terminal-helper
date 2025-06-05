#!/usr/bin/env bash
set -eu

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 0. User-configurable paths & jobs
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
: "${DOWNLOADS:=$HOME/downloads}"
: "${EXTRACTS:=$HOME/extracts}"
: "${INSTALLS:=$HOME/installs}"
: "${MAKE_JOBS:=$(nproc)}"

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 1. Version
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
set_python_version() {
    PYTHON_VER="${PYTHON_VER:-3.13.3}"
    echo "[INFO] Setting Python version to $PYTHON_VER"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 2. Download
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
download_python() {
    local log="$DOWNLOADS/python/$PYTHON_VER/download.log"
    mkdir -p "$DOWNLOADS/python/$PYTHON_VER"
    echo "[INFO] Downloading Python v$PYTHON_VER to $DOWNLOADS/python/$PYTHON_VER"
    wget -q --show-progress \
         "https://www.python.org/ftp/python/$PYTHON_VER/Python-$PYTHON_VER.tgz" \
         -O "$DOWNLOADS/python/$PYTHON_VER/Python-$PYTHON_VER.tgz" \
         2>&1 | tee "$log"

    if grep -qi "error" "$log"; then
        echo "[ERROR] Download failed; see $log"
        return 1
    else
        echo "[OK] Python download completed"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 3. Extract
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
extract_python() {
    local src_dir="$DOWNLOADS/python/$PYTHON_VER"
    local log="$src_dir/extract.log"

    echo "[INFO] Extracting Python tarball to $EXTRACTS/python/$PYTHON_VER/"
    mkdir -p "$EXTRACTS/python/$PYTHON_VER"
    tar -xzf "$src_dir/Python-$PYTHON_VER.tgz" \
        -C "$EXTRACTS/python/$PYTHON_VER" \
        --strip-components=1 \
        2>&1 | tee "$log"

    if [ ! -d "$EXTRACTS/python/$PYTHON_VER" ]; then
        echo "[ERROR] Extraction failed; directory missing"
        return 1
    else
        echo "[OK] Python extracted successfully"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 4. Configure
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
configure_python() {
    local src="$EXTRACTS/python/$PYTHON_VER"
    local log="$src/configure.log"
    local openssl_dir="$INSTALLS/openssl/${OPENSSL_VER:-1.1.1w}"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Configuring Python..."
    ./configure --prefix="$INSTALLS/python/$PYTHON_VER" \
                --enable-shared \
                --with-openssl="$openssl_dir" \
                --enable-optimizations \
        2>&1 | tee "$log"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 5. Build
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
build_python() {
    local src="$EXTRACTS/python/$PYTHON_VER"
    local log="$src/make.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Building Python..."
    make clean 2>/dev/null || true
    make -j"$MAKE_JOBS" 2>&1 | tee "$log"

}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 6. Install
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
install_python() {
    local src="$EXTRACTS/python/$PYTHON_VER"
    local log="$src/install.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Installing Python..."
    make install 2>&1 | tee "$log"

    if [ -x "$INSTALLS/python/$PYTHON_VER/bin/python3" ]; then
        echo "[OK] Python installed at $INSTALLS/python/$PYTHON_VER"
    else
        echo "[ERROR] Installation failed; python3 missing"
        return 1
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 7. Verify
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
check_python() {
    local prefix="$INSTALLS/python/$PYTHON_VER"
    local log="$prefix/check.log"

    echo "=== Python Installation Check ===" | tee "$log"
    echo "[INFO] Binaries:" | tee -a "$log"
    ls "$prefix/bin/" | tee -a "$log"

    echo "[INFO] Shared libs:" | tee -a "$log"
    ls "$prefix/lib/" | tee -a "$log"
    echo "[OK] Verification complete ⇒ $log"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Main
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
main() {
    set_python_version
    download_python
    extract_python
    configure_python
    build_python
    install_python
    check_python
    echo "[ALL DONE] Python v$PYTHON_VER is ready under $INSTALLS/python/$PYTHON_VER"
}
