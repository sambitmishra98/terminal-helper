# Installing software from source

This repository no longer carries build recipes for standard packages (GCC,
Open MPI, MPICH, UCX, OpenSSL, CPython, OSU, libffi, …). Those are common
knowledge to an LLM: ask Claude Code or Codex to generate the build for your
machine. What this repository does own is the **convention** every install
must follow, so that environments stay reproducible across machines.

## The contract

With `set_paths <scratch-root>` loaded (see `docs/path-contract.md`):

1. **Download** archives to `$DOWNLOADS/<name>/<version>/`.
2. **Extract** source trees to `$EXTRACTS/<name>/<version>/`.
3. **Install** with `--prefix=$INSTALLS/<name>/<version>`.
4. **Register** the install in the current shell:

   ```bash
   add_installation_to_path <name> <version> "$INSTALLS" [--quiet]
   ```

   This prepends `bin/`, `lib/`, `lib64/`, `include/`, and `pkgconfig/`
   subdirectories (when present) to `PATH`, `LD_LIBRARY_PATH`,
   `LIBRARY_PATH`, `CPATH`, and `PKG_CONFIG_PATH`.
   `remove_all_installation_paths` restores the shell's original `PATH` and
   clears the library variables.

## Worked example (UCX 1.18.0)

```bash
set_paths /scratch
wget "https://github.com/openucx/ucx/releases/download/v1.18.0/ucx-1.18.0.tar.gz" \
     -P "$DOWNLOADS/ucx/1.18.0"
mkdir -p "$EXTRACTS/ucx/1.18.0"
tar -xf "$DOWNLOADS/ucx/1.18.0/ucx-1.18.0.tar.gz" -C "$EXTRACTS/ucx/1.18.0"
cd "$EXTRACTS/ucx/1.18.0/ucx-1.18.0"
./configure --prefix="$INSTALLS/ucx/1.18.0" && make -j "$(nproc)" && make install
add_installation_to_path ucx 1.18.0 "$INSTALLS"
```

## Ground rules for generated installers

- No root: everything under `$INSTALLS`; never `sudo make install`.
- Quote every expansion; no `eval`; fail loudly (`|| return 1`, not silent).
- Machine-specific flags (CUDA/ROCm roots, partitions, UCX transports) come
  from the machine profile, not from the recipe — see
  `docs/spitfire-site-notes.md` for Spitfire's known-good combinations.
