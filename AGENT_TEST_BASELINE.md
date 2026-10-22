# Agent Increment Test Baseline

This branch is the immutable starting point for automated incremental-development tests.

- Product source: `C:\Users\26909\Downloads\opencalc_harmonyos-main\opencalc_harmonyos-main`
- Product source form: downloaded snapshot without Git metadata
- Source description: OpenCalc HarmonyOS scientific-calculator snapshot
- Repository scaffold parent: `01b3773ebc7f4e2c85b2fd5de05722e2589beb85`
- Scientific mode: present (`sin`, `cos`, `tan`, inverse trigonometric functions, logarithms, constants)
- Angle modes: degrees and radians
- Percent expression support: present in the expression engine
- Visible percent button: absent from the keypad
- Reproducibility fix: source resources are tracked so a clean worktree can build independently

Only build wrappers were added to support execution from arbitrary Git worktrees. Feature work must branch from this ref; do not commit feature changes directly to this branch.
