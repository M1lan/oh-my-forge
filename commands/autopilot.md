---
name: autopilot
description: Full autonomous execution from idea to working code. Use when the user says "just do it" or "build me X".
---

Autopilot: {{parameters}}

Load the `autopilot` skill and follow its workflow.

Full pipeline:
1. **Clarify** the request (if ambiguous, ask 1-2 quick questions -- otherwise proceed)
2. **Plan** with the `plan` skill (or `ralplan` for high-risk work)
3. **Execute** the plan phase by phase
4. **Verify** each phase against its acceptance criteria
5. **Report** when done with evidence of completion

Rules:
- Stop and ask the user if you hit a Ground Truth contradiction
- Stop and ask if a destructive irreversible action is needed (drop table, force push, rm -rf outside workspace)
- Otherwise keep going until done
