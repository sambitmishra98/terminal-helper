# Add installer safely

Goal: add one installer or helper at a time without broad refactors.

Instructions:
- Inspect existing installers/helpers for patterns to follow.
- Confirm the tool name, version, and install root before editing.
- Keep the patch small and focused on a single installer/helper.
- Avoid destructive commands and broad recursive operations.
- Prefer `/scratch/.local` for downloads, extracts, installs, and caches.
- Run `bash -n` or `shellcheck` on any edited shell scripts if available.
- Show the diff and summarize what changed.
