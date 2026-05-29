# Refactor script safely

Goal: refactor one shell script at a time while preserving behavior.

Instructions:
- Inspect the target script and its call sites before changing anything.
- Keep the patch small, reversible, and scoped to the single script.
- Preserve existing behavior unless the task explicitly requests changes.
- Quote variables, avoid `eval`, and avoid broad recursive operations.
- Run `bash -n` or `shellcheck` on the edited script if available.
- Show the diff and summarize what changed.
