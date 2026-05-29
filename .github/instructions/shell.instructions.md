# Shell script instructions

- Inspect the script and its call sites before editing.
- Prefer bash and follow existing style and conventions.
- Quote variable expansions; avoid `eval` and broad recursive operations.
- Preserve behavior unless a task explicitly requests changes.
- Run `bash -n` or `shellcheck` on edited scripts when available.
