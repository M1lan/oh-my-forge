---
name: execute
description: Execute an existing plan file using the execute-plan skill. Pass the plan file path as the argument.
---

Execute the plan at: {{parameters}}

Load the `execute-plan` skill and follow its workflow exactly.

Rules:

- Treat the Ground Truth section as canonical.
- If anything in Ground Truth is contradicted by the codebase during execution, STOP and ask the user.
- Mark every task with `[ ]`, `[~]` (in progress), `[x]` (done), `[!]` (blocked), or `[-]` (skipped) as you go.
- Update task markers in the plan file itself as you work.
- Run verification steps from the plan's Verification Criteria section after each phase.
- At the end, report results with a summary table.
