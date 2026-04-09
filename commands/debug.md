---
name: debug
description: Interactive debugging session for a failing test or broken behavior.
---

Debug: {{parameters}}

Run as the `debugger` agent. Workflow:

1. **Reproduce** the failure locally. Capture exact command and output.
2. **Isolate** -- minimize the failing case until it's the smallest repro possible
3. **Hypothesize** -- state 2-3 candidate root causes
4. **Test each hypothesis** with a cheap experiment (add a log, read adjacent code, run a variant)
5. **Fix** -- apply the minimal fix
6. **Verify** -- re-run the original failure and a broader test pass
7. **Write a regression test** so this can't silently come back

Report each step. Cite evidence (`path:line`, test output) at every stage.
