#!/usr/bin/env bash

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 1. Version
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
set_libffi_version() {
    LIBFFI_VER="${LIBFFI_VER:-3.4.8}"
    echo "[INFO] Setting libffi version to $LIBFFI_VER"
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 2. Download
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
download_libffi() {
    local log="$DOWNLOADS/libffi/$LIBFFI_VER/download.log"
    mkdir -p "$DOWNLOADS/libffi/$LIBFFI_VER"
    echo "[INFO] Downloading libffi v$LIBFFI_VER to $DOWNLOADS/libffi/$LIBFFI_VER"
    wget -q --show-progress \
         "https://github.com/libffi/libffi/releases/download/v$LIBFFI_VER/libffi-$LIBFFI_VER.tar.gz" \
         -O "$DOWNLOADS/libffi/$LIBFFI_VER/libffi-$LIBFFI_VER.tar.gz" \
         2>&1 | tee "$log"

    if grep -qi "error" "$log"; then
        echo "[ERROR] Download failed; see $log"
        return 1
    else
        echo "[OK] libffi download completed"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 3. Extract
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
extract_libffi() {
    local src_dir="$DOWNLOADS/libffi/$LIBFFI_VER"
    local log="$src_dir/extract.log"

    echo "[INFO] Extracting libffi tarball to $EXTRACTS/libffi/$LIBFFI_VER/"
    mkdir -p "$EXTRACTS/libffi/$LIBFFI_VER"
    tar -xzf "$src_dir/libffi-$LIBFFI_VER.tar.gz" \
        -C "$EXTRACTS/libffi/$LIBFFI_VER" \
        --strip-components=1 \
        2>&1 | tee "$log"

    if [ ! -d "$EXTRACTS/libffi/$LIBFFI_VER" ]; then
        echo "[ERROR] Extraction failed; directory missing"
        return 1
    else
        echo "[OK] libffi extracted successfully"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 4. Configure
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
configure_libffi() {
    local src="$EXTRACTS/libffi/$LIBFFI_VER"
    local log="$src/configure.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Configuring libffi..."
    ./configure \
        --prefix="$INSTALLS/libffi/$LIBFFI_VER" 
        2>&1 | tee "$log"

    if grep -q "error" "$log"; then
        echo "[ERROR] Configuration errors detected; see $log"
        return 1
    else
        echo "[OK] libffi configured successfully"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 5. Build
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
build_libffi() {
    local src="$EXTRACTS/libffi/$LIBFFI_VER"
    local log="$src/make.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Building libffi..."
    make clean 2>/dev/null || true
    make -j 24 2>&1 | tee "$log"

    if grep -q "error" "$log"; then
        echo "[ERROR] Build errors detected; see $log"
        return 1
    else
        echo "[OK] libffi build succeeded"
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# 6. Install
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
install_libffi() {
    local src="$EXTRACTS/libffi/$LIBFFI_VER"
    local log="$src/install.log"

    cd "$src" || { echo "[ERROR] Cannot cd to $src"; return 1; }
    echo "[INFO] Installing libffi..."
    make install 2>&1 | tee "$log"

    if [ -f "$INSTALLS/libffi/$LIBFFI_VER/lib64/libffi.so" ]; then
        echo "[OK] libffi installed at $INSTALLS/libffi/$LIBFFI_VER"
    else
        echo "[ERROR] Installation failed; libffi.so missing"
        return 1
    fi
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Main
#––––––––––––––––––––––––––––––––––––––––––––––––––––––
main() {
    set_libffi_version
    download_libffi
    extract_libffi
    configure_libffi
    build_libffi
    install_libffi
    echo "[ALL DONE] libffi v$LIBFFI_VER is ready under $INSTALLS/libffi/$LIBFFI_VER"
}
