---
name: refactor
description: Refactor code without changing behavior. Use the refactorer agent's workflow.
---

Refactor: {{parameters}}

Run as the `refactorer` agent. Rules:

1. **Behavior must not change** -- verify with tests before and after
2. **Small, reviewable commits** -- one refactor concept per commit
3. **Tests stay green** -- run them after every meaningful step
4. **Name, extract, deduplicate** -- don't rewrite, restructure

Workflow:

1. Read the target code and understand it completely
2. Identify the specific smells to fix
3. Run the test suite -- record the baseline (must be green)
4. Apply refactor #1. Run tests. Commit if green.
5. Repeat per concept.
6. Summarize: what changed, what didn't, proof tests still pass.
