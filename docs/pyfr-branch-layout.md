# PyFR branch layout

PyFR development branches live under the GitHub workspace tree:

```
/scratch/.github/sambitmishra98/PyFR/<branch-name>
```

Each branch (or version) has a matching Python virtual environment at:

```
/scratch/.venvs/sambitmishra98/PyFR/<branch-name>
```

## Why one venv per branch/version

- Keeps dependencies isolated across branches and experiments.
- Avoids cross-contamination from build artifacts.
- Makes it easy to switch contexts without reinstalling or rebasing.
