#!/usr/bin/env bash

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 1. Version
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
set_openssl_version() {
    OPENSSL_VER="${OPENSSL_VER:-1.1.1w}"
    echo "[INFO] Setting OpenSSL version to $OPENSSL_VER"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 2. Download
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
download_openssl() {
    local log="$DOWNLOADS/openssl/$OPENSSL_VER/download.log"
    mkdir -p "$DOWNLOADS/openssl/$OPENSSL_VER"
    echo "[INFO] Downloading OpenSSL v$OPENSSL_VER to $DOWNLOADS/openssl/$OPENSSL_VER"
    wget -q "https://www.openssl.org/source/openssl-$OPENSSL_VER.tar.gz" \
         -O "$DOWNLOADS/openssl/$OPENSSL_VER/openssl-$OPENSSL_VER.tar.gz" \
         2>&1 | tee "$log"

    if grep -qi "error" "$log"; then
        echo "[ERROR] Download failed; see $log"
        return 1
    else
        echo "[OK] OpenSSL download completed"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 3. Extract
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
extract_openssl() {
    local src_dir="$DOWNLOADS/openssl/$OPENSSL_VER"
    local log="$src_dir/extract.log"

    echo "[INFO] Extracting OpenSSL tarball to $EXTRACTS/openssl/$OPENSSL_VER/"
    mkdir -p "$EXTRACTS/openssl/$OPENSSL_VER"
    tar -xzf "$src_dir/openssl-$OPENSSL_VER.tar.gz" \
        -C "$EXTRACTS/openssl/$OPENSSL_VER" \
        --strip-components=1 \
        2>&1 | tee "$log"

    if [ ! -d "$EXTRACTS/openssl/$OPENSSL_VER" ]; then
        echo "[ERROR] Extraction failed; directory missing"
        return 1
    else
        echo "[OK] OpenSSL extracted successfully"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 4. Configure
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
configure_openssl() {
    local src="$EXTRACTS/openssl/$OPENSSL_VER"
    local log="$src/configure.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Configuring OpenSSL..."
    ./config --prefix="$INSTALLS/openssl/$OPENSSL_VER" \
              --openssldir="$INSTALLS/openssl/$OPENSSL_VER/ssl" \
              shared zlib  \
        2>&1 | tee "$log"

    if grep -qi "error" "$log"; then
        echo "[ERROR] Configuration errors detected; see $log"
        return 1
    else
        echo "[OK] OpenSSL configured successfully"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 5. Build
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
build_openssl() {
    local src="$EXTRACTS/openssl/$OPENSSL_VER"
    local log="$src/make.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Building OpenSSL..."
    make clean 2>/dev/null || true
    make -j"$MAKE_JOBS" 2>&1 | tee "$log"

    if grep -qi "error" "$log"; then
        echo "[ERROR] Build errors detected; see $log"
        return 1
    else
        echo "[OK] OpenSSL build succeeded"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 6. Install
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
install_openssl() {
    local src="$EXTRACTS/openssl/$OPENSSL_VER"
    local log="$src/install.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Installing OpenSSL..."
    make install 2>&1 | tee "$log"

    if [ -f "$INSTALLS/openssl/$OPENSSL_VER/lib/libcrypto.so" ] && \
       [ -f "$INSTALLS/openssl/$OPENSSL_VER/lib/libssl.so" ]; then
        echo "[OK] OpenSSL installed at $INSTALLS/openssl/$OPENSSL_VER"
    else
        echo "[ERROR] Installation failed; .so files missing"
        return 1
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 7. Verify
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
check_openssl() {
    local prefix="$INSTALLS/openssl/$OPENSSL_VER"
    local log="$prefix/check.log"

    echo "=== OpenSSL Installation Check ===" | tee "$log"
    echo "[INFO] Libraries:" | tee -a "$log"
    ls "$prefix/lib/" | tee -a "$log"

    echo "[INFO] Headers:" | tee -a "$log"
    ls "$prefix/include/openssl" | tee -a "$log"
    echo "[OK] Verification complete ⇒ $log"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Main
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
main() {
    set_openssl_version
    download_openssl
    extract_openssl
    configure_openssl
    build_openssl
    install_openssl
    echo "[ALL DONE] OpenSSL v$OPENSSL_VER is ready under $INSTALLS/openssl/$OPENSSL_VER"
}