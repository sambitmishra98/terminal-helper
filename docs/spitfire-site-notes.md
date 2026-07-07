# Spitfire site notes

Site knowledge extracted from the retired `lib/installers/installations/Spitfire/`
and `lib/clusters/Spitfire_*` job snapshots (deleted in the July 2026 cleanup —
see `docs/audit-2026-07.md` §6). This file is the seed for the Spitfire machine
profile planned in Phase 3. Personal usernames and old mount roots are
deliberately omitted; use `$SCRATCH`-derived paths from `bin/set-paths`.

## Node classes and partitions

| Nodes | Partition | Accelerators | Typical job shape |
|-------|-----------|--------------|-------------------|
| `spitfire-ng[19,20]` | `all` | NVIDIA (CUDA), 4 GPUs/node | `--gres=gpu:4 --cpus-per-gpu=4 --exclusive` |
| `spitfire-ng[28,29]` | `amd` | AMD (ROCm), 3 GPUs/node | `--gres=gpu:3 --cpus-per-gpu=4 --mem-per-gpu=20G --gpu-bind=closest` |
| `ng24` | — | (install-tagged builds) | UCX/MPICH installs are tagged `ng24` |

Job prologue used by every snapshot:

```bash
. /etc/profile.d/modules.sh
. ~/.bashrc
```

## Hostname-dispatched environment (from `setup-login.sh`)

The login/interactive bootstrap dispatched on `hostname -s`:

- `spitfire-ng01…ng20`: CUDA 12.6 from `/usr/local`, ROCm userspace 7.0.0 from
  `$INSTALLS`, `UCX_TLS=self,sm,dc_mlx5,rc_mlx5,cuda,cuda_copy,cuda_ipc`
- `spitfire-ng22…ng29`: CUDA 12.6.0 toolkit from `$INSTALLS`, ROCm 7.0.0 from
  `/opt`, `UCX_TLS=self,sm,dc_mlx5,rc_mlx5,rocm_copy,rocm_ipc`
- fallback: both from system roots, `UCX_TLS=self,sm,dc_mlx5,rc_mlx5`

Common to all node classes:

```bash
export OMP_PROC_BIND=TRUE OMP_PLACES=cores OMP_NUM_THREADS=1
export UCX_NET_DEVICES=mlx5_0:1
```

## Toolchain versions that worked (2025–2026)

Registered via `add_installation_to_path <name> <version> <root>`
(`lib/common/add_installation.sh`):

| Package | Version | Root |
|---------|---------|------|
| gcc | 12.3.0 | site package tree (pre-`.local` layout) |
| cuda | 12.6 / 12.6.0 toolkit | `/usr/local` or `$INSTALLS` |
| rocm | 6.4.1 → 7.0.0 | `/opt` or `$INSTALLS` |
| ucx | `master` (cuda/rocm builds); 1.20.0 (`ng24`) | `$INSTALLS` |
| openmpi | `main` (`ompi-cuda` / `ompi-rocm` builds) | `$INSTALLS` |
| mpich | 4.3.2 (`ng24`) | `$INSTALLS` |
| libffi | 3.4.8 | `$INSTALLS` |
| openssl | 1.1.1w | `$INSTALLS` |
| python | 3.13.3 | `$INSTALLS` |
| scotch | 7.0.10 | `$INSTALLS` |
| libspacialindex (rtree) | — | `$INSTALLS` |

## Ascent (in-situ visualization) — working combinations

Built from Alpine-DAV `ascent.git` (branch `develop`, `--recursive`) using the
upstream driver: `env prefix="$prefix" enable_mpi=ON scripts/build_ascent/build_ascent.sh`.

Known-good install tags and companion libraries:

- `develop_cuda_ucx-master_ompi-main` — conduit v0.9.4, vtk-m v2.3.0
- `develop_rocm_ucx-master_ompi-main` — conduit v0.9.4, vtk-m v2.3.0
- `ng24/develop` (MPICH 4.3.2 stack) — conduit v0.9.5

Layout quirk: the upstream script installs under
`.../scripts/build_ascent/install/`, and the MPI library lands at
`<install>/ascent-checkout/lib/libascent_mpi.so` — that full path is what
`PYFR_ASCENT_MPI_LIBRARY_PATH` must point to.

## PyFR native-library environment

```bash
export PYFR_XSMM_LIBRARY_PATH=<libxsmm-build>/lib/libxsmm.so      # built from git
export PYFR_METIS_LIBRARY_PATH=<metis-build>/lib/libmetis.so      # built from git
export PYFR_SCOTCH_LIBRARY_PATH=$INSTALLS/scotch/7.0.10/lib64/libscotch.so
export PYFR_KAHIP_LIBRARY_PATH=$DOWNLOADS/kahip/deploy/libkahip.so
export LD_PRELOAD="$INSTALLS/scotch/7.0.10/lib64/libscotcherr.so${LD_PRELOAD:+:$LD_PRELOAD}"
```

(xsmm/metis historically lived in a pre-`.local` `git/` tree; place new builds
under `$INSTALLS`.)

## MPICH-stack venv

The `ng24` MPICH stack kept its PyFR venv co-located with the MPI install:
`$INSTALLS/mpich/4.3.2/ng24/venv/pyfr`. The canonical convention is one venv
per PyFR branch under `$PYFR_VENVS/<branch>`; treat the co-located venv as a
site-specific exception.
