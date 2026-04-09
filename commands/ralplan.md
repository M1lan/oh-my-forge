---
name: ralplan
description: Create a consensus-tested plan using the ralplan skill (planner + architect + critic iterative refinement). Use when the plan must be near-bulletproof before execution.
---

Create a ralplan for: {{parameters}}

Load the `ralplan` skill and follow its workflow exactly.

Run at least 2 iterations of (draft -> architect review -> critic review -> revise) until the critic's verdict is READY. Capture each iteration's deltas.

Output: `plans/<current-date>-<task-slug>-v1.md` with a "Review History" section showing the iterations.

Do not execute the plan. Stop after the plan file is written.
