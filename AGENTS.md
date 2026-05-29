# AGENTS

Operational rulebook for ChatGPT, GitHub Copilot CLI, and local AI assistants
working in this repository.

## Workflow

Follow the sequence: inspect → plan → edit → test → review. Keep plans brief and
patches small and reversible.

## Safety and scope

- Inspect relevant files before editing.
- Do not edit files outside this repository.
- Do not push, force-push, delete, or run destructive commands unless explicitly
  approved.
- Preserve backward compatibility unless a task explicitly requests a clean
  v2-style cleanup.

## Scratch contract

- `/scratch` is the explicit root.
- `set_paths` must receive a scratch-root argument and should error if none is
  provided.

## Shell scripts

- Prefer bash and follow existing script style.
- Quote variable expansions and avoid broad recursive operations.
- If available, run `bash -n` or `shellcheck` on edited scripts.
- Refactor only when explicitly asked.

## PyFR helpers

- Keep environment setup, source-code edits, run-configuration edits, test
  execution, and numerical verification clearly separated.
- State which layer is being changed and avoid mixing concerns in one patch.
