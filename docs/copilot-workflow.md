# Copilot workflow

Use the standard sequence: inspect → plan → edit → test → review. Keep patches
small and reversible.

## Asking for bounded patches

When requesting changes, specify:

- Exact files to edit.
- Desired scope (documentation-only, script change, etc.).
- Constraints (no refactor, no destructive commands).
- Verification steps to run.

## Guardrails

- Do not push, force-push, or delete unless explicitly asked.
- Do not refactor broadly unless explicitly asked.
- Do not edit outside the repository.
