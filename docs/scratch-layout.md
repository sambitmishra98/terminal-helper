# Scratch layout

This repository assumes `/scratch` is the explicit root for all research work
and helpers. The directories below are the canonical layout.

| Path | Purpose |
| --- | --- |
| `/scratch/.github/` | GitHub repositories under active development. |
| `/scratch/.venvs/` | Python virtual environments. |
| `/scratch/.local/` | Ready-to-use external material: clones, downloads, extracts, installs, caches. |
| `/scratch/supplementary/` | Reusable meshes/input data (e.g., `*.msh`); not synced by default. |
| `/scratch/EFFORTS/` | Actual research runs and outputs, organized case-first. |
| `/scratch/.workspaces/` | VS Code workspace files only. |
| `/scratch/.containers/` | Reserved for future container/workshop recipes. |

## Example tree

```text
/scratch
├─ .github/
│  └─ sambitmishra98/
│     └─ PyFR/
│        └─ feature-branch/
├─ .venvs/
│  └─ sambitmishra98/
│     └─ PyFR/
│        └─ feature-branch/
├─ .local/
│  ├─ downloads/
│  ├─ extracts/
│  └─ installs/
├─ supplementary/
│  └─ meshes/
├─ EFFORTS/
│  └─ case-name/
├─ .workspaces/
└─ .containers/
```
