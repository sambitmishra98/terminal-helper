# Terminal Helper
*Handy shell utilities for quickly wiring up local paths, HPC scratch areas, and PyFR-specific tooling.*

## Overview
A collection of small Bash helpers for my day‑to‑day PyFR and cluster work.
When coming back after a long break, skim the **Quick‑start** section below to
recall the typical sourcing sequence. Each script is also summarised in the
table under **Script reference**.


---

## Prerequisites

* Bash shell (tested with bash 5.x)
* Git and Python 3 available in your `PATH`
* HPC modules (`module` command) if running on a cluster
* A writable scratch directory for `set_paths`

---

## Quick-start

~~~
# Clone the repo anywhere you like, then:
source installations-linker.sh          # brings in add_installation_to_path
source local-only-paths-template.sh     # defines local ↔ remote path variables
source set-paths-dir.sh                 # gives you set_paths & helpers
~~~

### One-shot launcher

~~~
source terminal_addon.sh <repo-root>
~~~

---

## Script reference
Use this table as a quick reminder of what each helper exposes and how to call it.

| File (source it?)                       | Commands exposed / functions                | Inputs                                   | Outputs / exports                                                                 |
|-----------------------------------------|----------------------------------------------|------------------------------------------|-----------------------------------------------------------------------------------|
| **installations-linker.sh**<br>source   | add_installation_to_path <name> <version> <install_root> | name (e.g. mpich)<br>version (e.g. 1.18.0)<br>install_root (prefix path) | Extends PATH, CPATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH, etc., then echoes “Added <name>” |
| **local-only-paths-template.sh**<br>source | (none – defines variables)                   | none                                     | Sets local_user, local_ip, dest_local, src_local, plus matching consciousness_* vars |
| **set-paths-dir.sh**<br>source          | set_paths <scratch_dir><br>check_paths<br>create_paths<br>print_paths | scratch_dir (absolute path to scratch) | Prints status lines or mkdir traces                                                |
| **terminal_addon.sh**<br>source           | (wrapper – no new funcs)                     | root_dir (path to repo)                 | Sources profession/.../setup-worktree.sh and .../setup-venv.sh                    |
| **setup-worktree.sh**<br>source        | init_worktree [branch]                       | branch (optional)                        | Creates or checks out a Git worktree for your PyFR fork                           |
| **setup-venv.sh**<br>source          | (no public funcs)                            | none                                     | Creates .venv, activates it, installs PyFR + extras                               |

---

## Shell style

* Scripts start with `#!/usr/bin/env bash`.
* Executable files include `set -eu` after the shebang.
* Quote variable expansions and use `$(( ... ))` for arithmetic.
---

## Directory hints

* **clusters/** – rsync helpers and SLURM/SSH config snippets  
* **installations/** – one-liner installers for UCX, MPICH, ROCm, etc.  
* **profession/** – house-kept scripts tied to your PyFR fork

---

## Next steps

1. **Test drive** – clone the repo on spitfire-ng29, source the three core files, and run `check_paths` to ensure all scratch-dir variables resolve.  
2. **Worktree refresh** – run `init_worktree feature/fast-io` (or any branch) and verify the remote URL points to your GitHub fork.  
3. **Virtual-env sanity** – let `setup-venv.sh` create the environment; confirm `python -m pyfr --version` reports the expected commit.

---

## Examples

### set_paths

~~~bash
source set-paths-dir.sh
set_paths "/scratch/$USER"
create_paths    # make the folders if needed
check_paths     # verify they exist
~~~

### add_installation_to_path

~~~bash
source installations-linker.sh
add_installation_to_path mpich 4.3.0 "$INSTALLS"
~~~

### setup_worktree

~~~bash
source profession/sambitmishra98_pyfr/setup-worktree.sh
setup_worktree --base case/c3900 --trunk develop --add feature/foo --add feature/bar
~~~

### Combining scripts on a cluster

Cluster jobs typically load the module system and then source the helper scripts:

~~~bash
. /etc/profile.d/modules.sh
source set-paths-dir.sh
source installations-linker.sh
set_paths "/scratch/$USER"
add_installation_to_path mpich 4.3.0 "$INSTALLS"
~~~

All directory variables like `EFFORTS`, `VENVS` and `WORKSPACES` are derived from
`$SCRATCH` as set by `set_paths`.

## Contributing

Before committing changes, run `shellcheck` on all shell scripts:

```
shellcheck $(git ls-files '*.sh')
```

The GitHub Actions workflow will also verify this on every push.
