# Path contract

All paths derive from the explicit scratch root `/scratch`. The `set_paths`
helper must receive the scratch root as its argument and should fail if no
argument is provided.

## Expected variables

- `SCRATCH`: `/scratch`
- `GITHUB`: `/scratch/.github`
- `LOCAL`: `/scratch/.local`
- `VENVS`: `/scratch/.venvs`
- `WORKSPACES`: `/scratch/.workspaces`
- `SUPPLEMENTARY`: `/scratch/supplementary`
- `EFFORTS`: `/scratch/EFFORTS`

## PyFR branch paths

- PyFR branches: `/scratch/.github/sambitmishra98/PyFR/<branch-name>`
- PyFR venvs: `/scratch/.venvs/sambitmishra98/PyFR/<branch-name>`

These paths define the canonical layout used by terminal-helper and should be
preserved by any script changes.
