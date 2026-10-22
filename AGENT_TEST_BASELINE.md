# Basic Calculator Agent Test Baseline

This branch is the immutable starting point for automated incremental-development tests.

- Branch: `agent-test/baseline-basic-calculator`
- Parent baseline: `agent-test/baseline-opencalc` (`03fc67d`)
- Product surface: decimal numbers, parentheses, `+`, `-`, `×`, `÷`, `AC`, backspace, and equals
- Scientific mode and scientific functions: absent from UI, preferences, expression preprocessing, and calculation engine
- Visible percent button and percent implementation: absent
- Guard command: `powershell -ExecutionPolicy Bypass -File tools/verify-basic-calculator-baseline.ps1`
- Build command: `opencalc\run-build-wt.bat`

This ref intentionally removes the pre-existing scientific calculator capabilities so they can be exercised as genuine incremental-development tasks. Feature work must branch from this ref; do not commit feature changes directly to this branch.
