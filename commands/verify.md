---
name: verify
description: Run evidence-based verification of completion claims against a plan or task list. Produces DONE / NOT-DONE verdict per claim.
---

Verify completion of: {{parameters}}

Load the `verify` skill and follow its workflow exactly.

For each claim of completion, gather evidence:

1. **Run tests** if applicable (capture full output)
2. **Inspect files** that should have changed (cite `path:line`)
3. **Check behavior** at runtime where possible
4. **Compare against acceptance criteria** from the plan or task

Output: a verification report with one row per claim and a DONE/NOT-DONE verdict + evidence pointer.

Never mark something DONE without evidence. "I wrote the code" is not evidence; "I ran `pytest` and it printed 12 passed" is.
