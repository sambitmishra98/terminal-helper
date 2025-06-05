#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../colors.sh"

INFO="${BLUE}[INFO]${RESET}"
OK="${GREEN}[OK]${RESET}"
ERROR="${RED}[ERROR]${RESET}"
WARN="${YELLOW}[WARN]${RESET}"
set_mpich_version() {
    MPICH_VER="4.3.0"
    echo -e "${INFO} Setting MPICH version to $MPICH_VER"
}

download_mpich() {
    local log="$DOWNLOADS/mpich/$MPICH_VER/download.log"
    mkdir -p "$DOWNLOADS/mpich/$MPICH_VER"
    echo -e "${INFO} Downloading MPICH v$MPICH_VER to $DOWNLOADS/mpich/$MPICH_VER"
    wget "https://www.mpich.org/static/downloads/4.3.0/mpich-4.3.0.tar.gz" \
         -O "$DOWNLOADS/mpich/$MPICH_VER/mpich-$MPICH_VER.tar.gz" \
         2>&1 | tee "$log"

    if grep -q "ERROR" "$log"; then
        echo -e "${ERROR} Download failed; see $log"
        return 1
    else
        echo -e "${OK} MPICH download completed"
    fi
}

extract_mpich() {
    local src_dir="$DOWNLOADS/mpich/$MPICH_VER"
    local log="$src_dir/extract.log"

    echo -e "${INFO} Extracting MPICH tarball to $EXTRACTS/mpich/$MPICH_VER/"
    mkdir -p "$EXTRACTS/mpich/$MPICH_VER"
    tar -xvf "$src_dir/mpich-$MPICH_VER.tar.gz" \
        -C "$EXTRACTS/mpich/$MPICH_VER" 2>&1 | tee "$log"

    if [ ! -d "$EXTRACTS/mpich/$MPICH_VER/mpich-$MPICH_VER" ]; then
        echo -e "${ERROR} Extraction failed; directory missing"
        return 1
    else
        echo -e "${OK} MPICH extracted successfully"
    fi
}

autogen_mpich() {
    local src="$EXTRACTS/mpich/$MPICH_VER/mpich-$MPICH_VER"
    local log="$src/autogen.log"

    cd "$src" || { echo -e "${ERROR} Cannot cd to $src"; return 1; }
    echo -e "${INFO} Generating autoconf scripts..."
    ./autogen.sh 2>&1 | tee "$log"

    if grep -q "configure" "$log"; then
        echo -e "${OK} Autogen generated configure script"
    else
        echo -e "${ERROR} Autogen did not generate configure script; see $log"
        return 1
    fi
}

configure_mpich() {
    local src="$EXTRACTS/mpich/$MPICH_VER/mpich-$MPICH_VER"
    local log="$src/configure.log"

    cd "$src" || { echo -e "${ERROR} Cannot cd to $src"; return 1; }
    echo -e "${INFO} Configuring MPICH..."
    ./configure \
        --prefix="$INSTALLS/mpich/$MPICH_VER" \
        --with-device=ch4:ucx \
        --with-ucx="$INSTALLS/ucx-cuda/$UCX_VER" \
        --with-cuda="/usr/local/cuda" \
        --with-slurm \
        --enable-shared \
        --enable-fast=all,O3 \
        --enable-g=none \
        2>&1 | tee -a "$log"

    # Validate configure
    for flag in ch4:ucx cuda hip slurm; do
      if grep -q "$flag" "$log"; then
        echo -e "${OK} Found configure flag: $flag"
      else
        echo -e "${WARN} Missing $flag in configure log"
      fi
    done
}

make_mpich() {
    local src="$EXTRACTS/mpich/$MPICH_VER/mpich-$MPICH_VER"
    local log="$src/make.log"

    cd "$src" || return 1
    echo -e "${INFO} Building MPICH..."
    make clean 2>&1
    make -j"${MAKE_JOBS:-16}" 2>&1 | tee "$log"

    if grep -q "error:" "$log"; then
        echo -e "${ERROR} Build errors detected; see $log"
        return 1
    else
        echo -e "${OK} MPICH build succeeded"
    fi
}


install_mpich() {
    local src="$EXTRACTS/mpich/$MPICH_VER/mpich-$MPICH_VER"
    local log="$src/install.log"

    cd "$src" || return 1
    echo -e "${INFO} Installing MPICH..."
    make install 2>&1 | tee "$log"

    if [ -x "$INSTALLS/mpich/$MPICH_VER/bin/mpicc" ]; then
        echo -e "${OK} MPICH installed at $INSTALLS/mpich/$MPICH_VER"
    else
        echo -e "${ERROR} Installation failed; mpicc missing"
        return 1
    fi
}

check_mpich() {
    local prefix="$INSTALLS/mpich/$MPICH_VER"
    local log="$prefix/check.log"
    local cuda_root="${CUDA_ROOT:-/usr/local/cuda}"   # adjust if you use modules

    echo -e "${BOLD}=== MPICH Version & Configuration ===${RESET}" | tee  "$log"
    "$prefix/bin/mpichversion"                   2>&1 | tee -a "$log"

    echo; echo -e "${BOLD}=== mpicc -show ===${RESET}"                 | tee -a "$log"
    "$prefix/bin/mpicc" -show                   2>&1 | tee -a "$log"

    echo; echo -e "${BOLD}=== ucx_info cuda transport check ===${RESET}" | tee -a "$log"
    if ucx_info -d | grep -q cuda; then
        echo -e "${OK} UCX sees the cuda transport"   | tee -a "$log"
    else
        echo -e "${WARN} cuda transport NOT detected" | tee -a "$log"
    fi

    ########################################################################
    #  Tiny CUDA-Aware ping-pong (device-buffer Send/Recv)
    ########################################################################
cat > test_cuda_pingpong.c <<'EOF'
#include <mpi.h>
#include <stdio.h>
#include <cuda_runtime.h>

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    int rank; MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    int h_val = rank;
    int *d_buf;
    cudaMalloc((void**)&d_buf, sizeof(int));          // ← cast here
    cudaMemcpy(d_buf, &h_val, sizeof(int), cudaMemcpyHostToDevice);

    int peer = (rank + 1) % 2;
    MPI_Sendrecv(d_buf, 1, MPI_INT, peer, 0,
                 d_buf, 1, MPI_INT, peer, 0,
                 MPI_COMM_WORLD, MPI_STATUS_IGNORE);

    cudaMemcpy(&h_val, d_buf, sizeof(int), cudaMemcpyDeviceToHost);
    printf("Rank %d received %d via GPU buffer\n", rank, h_val);

    cudaFree(d_buf);
    MPI_Finalize();
    return 0;

}
EOF

    echo; echo -e "${BOLD}=== compiling CUDA-aware ping-pong ===${RESET}" | tee -a "$log"
    "$prefix/bin/mpicc" test_cuda_pingpong.c \
        -I"${cuda_root}/include" -L"${cuda_root}/lib64" -lcudart \
        -o test_cuda_pingpong                        2>&1 | tee -a "$log"

    if [[ ! -x ./test_cuda_pingpong ]]; then
        echo -e "${ERROR} compile failed; see $log"
        rm -f test_cuda_pingpong.c
        return 1
    fi

    echo; echo -e "${BOLD}=== running ping-pong on 2 ranks ===${RESET}" | tee -a "$log"
    srun --mpi=pmi2 -n 2 ./test_cuda_pingpong       2>&1 | tee -a "$log"

    echo; echo -e "${OK} MPICH CUDA-aware check complete ⇒ $log" | tee -a "$log"
    rm -f test_cuda_pingpong test_cuda_pingpong.c
}
