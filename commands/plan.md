---
name: plan
description: Create a structured implementation plan and write it to plans/YYYY-MM-DD-<slug>-v1.md. Use for non-trivial work before any code changes.
---

Create an implementation plan for: {{parameters}}

Load the `plan` skill and follow its workflow exactly.

Deliverables:

1. A plan file at `plans/<current-date>-<task-slug>-v1.md` matching the skill's structure.
2. Explicit Ground Truth, Objective, Phases with tasks, Verification Criteria, and Rollback sections.
3. Mark the plan complete with `[ ]` markers ready for execution.

Do not write any code. Do not modify existing files (except creating the plan file).
