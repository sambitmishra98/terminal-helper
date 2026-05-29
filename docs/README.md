# terminal-helper
**Entry point for humans and AI assistants. Start here.**

terminal-helper is a /scratch-based helper repository for local Ubuntu, WSL2,
and HPC cluster setups. It standardizes scratch paths, keeps PyFR branches and
virtual environments organized, and provides small shell helpers for daily use.

## Quick start

```bash
# From the repo root
source bin/set-paths
set_paths /scratch
create_paths

# Optional: load PyFR worktree + venv helpers
source bin/terminal-env "$PWD"
```

## Scratch-root model

`/scratch` is the explicit root. Every path in this repository is derived from
it, and `set_paths` must receive the scratch root as its argument (it should
error if no argument is given). See the full contract in
[docs/path-contract.md](docs/path-contract.md).

## Directory roles (canonical layout)

- `/scratch/.github/` — GitHub repositories under active development.
- `/scratch/.venvs/` — Python virtual environments.
- `/scratch/.local/` — ready-to-use external material (clones, downloads,
  extracts, installs, caches).
- `/scratch/supplementary/` — reusable meshes/input files (e.g., `*.msh`); not
  synced by default.
- `/scratch/EFFORTS/` — actual research work and simulation runs (case-first).
- `/scratch/.workspaces/` — VS Code workspace files only.
- `/scratch/.containers/` — reserved for future container/workshop recipes.

Details and examples are in [docs/scratch-layout.md](docs/scratch-layout.md).

## PyFR branch and venv convention

- PyFR branches live at `/scratch/.github/sambitmishra98/PyFR/<branch-name>`.
- One Python venv per branch/version lives at
  `/scratch/.venvs/sambitmishra98/PyFR/<branch-name>`.

This keeps dependencies isolated and makes switching branches predictable. See
[docs/pyfr-branch-layout.md](docs/pyfr-branch-layout.md).

## Large-file policy

Large artifacts (meshes, `*.pyfrm`, `*.pyfrs`, `*.vtu`, big CSVs, logs, case
outputs) stay outside this repository. Use `/scratch/supplementary` and
`/scratch/EFFORTS`, which are not meant to be synced by default. See
[docs/large-file-policy.md](docs/large-file-policy.md).

## Safe contribution workflow

Inspect first, then make small, reviewable edits. Do not refactor working
scripts unless explicitly asked. Follow the standard workflow in
[docs/copilot-workflow.md](docs/copilot-workflow.md).

## Documentation index

- [Scratch layout](docs/scratch-layout.md)
- [Path contract](docs/path-contract.md)
- [PyFR branch layout](docs/pyfr-branch-layout.md)
- [Large-file policy](docs/large-file-policy.md)
- [Copilot workflow](docs/copilot-workflow.md)
