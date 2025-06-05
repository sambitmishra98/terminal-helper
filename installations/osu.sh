#!/usr/bin/env bash
###############################################################################
#  OSU Micro-Benchmarks (OMB) helper functions
#  Mirrors the UCX / MPICH style: version → download → extract → build
###############################################################################

download_osu() {
    local log="$DOWNLOADS/osu/download.log"
    mkdir -p "$DOWNLOADS/osu"
    echo "[INFO] Downloading OSU-MB → $DOWNLOADS/osu" | tee "$log"
    wget "https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.5-1.tar.gz" \
         -O "$DOWNLOADS/osu/osu-7.5-1.tar.gz" 2>&1 | tee -a "$log"

    if grep -q "ERROR" "$log"; then
        echo "[ERROR] Download failed; see $log"
        return 1
    else
        echo "[OK] Download complete"
    fi
}

extract_osu() {
    local log="$DOWNLOADS/osu/extract.log"
    echo "[INFO] Extracting OSU tarball → $EXTRACTS/osu" | tee "$log"
    mkdir -p "$EXTRACTS/osu"
    tar -xf "$DOWNLOADS/osu/osu-7.5-1.tar.gz" \
        -C  "$EXTRACTS/osu" 2>&1 | tee -a "$log"

    if [ ! -d "$EXTRACTS/osu/osu-micro-benchmarks-7.5-1" ]; then
        echo "[ERROR] Extraction failed; directory missing" | tee -a "$log"
        return 1
    fi
    echo "[OK] Extraction succeeded"
}

###############################################################################
# Helper to build (configure → make → install) either CPU-only or GPU-aware.
#   $1 = cpu  →  plain build
#   $1 = gpu  →  --enable-cuda build (needs $CUDA_ROOT or $EBROOTCUDA defined)
###############################################################################
_build_osu() {
    local mode=$1                 # cpu | gpu
    local src="$EXTRACTS/osu/osu-micro-benchmarks-7.5-1"
    local prefix="$INSTALLS/osu/$mode"
    local log_dir="$src/build-$mode"
    mkdir -p "$log_dir" "$prefix"

    cd "$src"

    # --- GPU build needs libcudart on the final link line -------------------
    # OSU’s configure does not add -lcudart automatically.  Inject via LIBS.
    if [[ $mode == gpu ]]; then
        export CUDA_ROOT="/usr/local/cuda"                 # adjust if needed
        export LIBS="-lcudart"                             # pull in CUDA runtime
        export LDFLAGS="-L${CUDA_ROOT}/lib64"              # library path
        CUDA_CONFIG_FLAGS="--enable-cuda --with-cuda=${CUDA_ROOT}"
    else
        unset LIBS LDFLAGS
        CUDA_CONFIG_FLAGS=""
    fi

    echo "[INFO] Configuring OSU ($mode) → $prefix"
    ./configure CC=mpicc CXX=mpicxx \
        ${CUDA_CONFIG_FLAGS} \
        --prefix="$prefix" 2>&1 | tee "$log_dir/configure.log"

    echo "[INFO] Building OSU ($mode)" | tee "$log_dir/make.log"
    make -j"${MAKE_JOBS:-16}" 2>&1 | tee -a "$log_dir/make.log"

    echo "[INFO] Installing OSU ($mode)" | tee "$log_dir/install.log"
    make install 2>&1 | tee -a "$log_dir/install.log"

    # Sanity check
    local exe="$prefix/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw"
    if [[ -x $exe ]]; then
        echo "[OK] OSU-$mode installed ⇒ $exe"
    else
        echo "[ERROR] OSU-$mode build failed; $exe missing"
        return 1
    fi
}

make_osu_cpu() { _build_osu cpu; }
make_osu_gpu() { _build_osu gpu; }

################################################################################
# OSU validation ‒ bandwidth smoke-tests (cpu + gpu)
################################################################################
check_osu() {
    local cpu_bw="$INSTALLS/osu/cpu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw"
    local gpu_bw="$INSTALLS/osu/gpu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw"

    # results folder with date-stamp to avoid clobbering
    local results_root="$INSTALLS/osu/results"
    local stamp=$(date +%Y-%m-%d_%H%M%S)
    local results_dir="$results_root/$stamp"
    mkdir -p "$results_dir"

    local log="$results_dir/osu_summary.log"
    echo "[INFO] OSU bandwidth checks ⇒ $results_dir" | tee  "$log"
    echo "[INFO] Using cpu_bw=$cpu_bw"                  | tee -a "$log"
    echo "[INFO] Using gpu_bw=$gpu_bw"                  | tee -a "$log"

    # helper: nodes, ranks-total, label, exe
    _run_osu () {
        local nodes=$1 ranks=$2 label=$3 exe=$4 outfile="$results_dir/$label.txt"
        echo "[INFO] $label"        | tee -a "$log"
        srun --mpi=pmi2 -N "$nodes" -n "$ranks" "$exe" 2>&1 | tee  "$outfile"
        # quick summary line (last bandwidth value)
        awk 'NF && $1+0==$1 {bw=$NF} END{printf("[OK]  %-28s  %s MB/s\n","'"$label"'",bw)}' "$outfile" | tee -a "$log"
    }

    # CPU tests
    [[ -x "$cpu_bw" ]] && {
        _run_osu 1 2  "cpu_within_node"   "$cpu_bw"
        _run_osu 2 2  "cpu_across_nodes"  "$cpu_bw"
    } || echo "[ERROR] CPU binary missing: $cpu_bw" | tee -a "$log"

    # GPU tests (skip if cuda build not present)
    if [[ -x "$gpu_bw" ]]; then
        # Ensure CUDA_VISIBLE_DEVICES or UCX vars are inherited from sbatch
        _run_osu 1 2  "gpu_within_node"   "$gpu_bw"
        _run_osu 2 2  "gpu_across_nodes"  "$gpu_bw"
    else
        echo "[WARN] GPU binary not found ⇒ skip GPU tests" | tee -a "$log"
    fi

    echo "[INFO] OSU checks complete.  Summary ⇢ $log"
}

