---
name: trace
description: Evidence-based debugging of a bug or failing behavior. Traces symptoms back to root cause with citations.
---

Trace the root cause of: {{parameters}}

Load the `tracer` skill and follow its workflow exactly.

Output:

1. **Symptom restated** precisely
2. **Reproduction steps** -- verified working repro
3. **Trace** -- stack/call-chain from symptom to root cause, each step cited with `path:line`
4. **Root cause** -- one sentence, specific
5. **Fix options** -- at least 2, with tradeoffs
6. **Verification plan** -- how to prove the fix works

Do not implement the fix unless explicitly asked. Stop at diagnosis.
