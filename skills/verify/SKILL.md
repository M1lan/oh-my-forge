---
name: verify
description: Turn "it should work" into concrete evidence that it actually does. Prefers existing tests first, then typecheck/build, then narrow direct checks, then manual validation. Reports only what was actually verified. Use before claiming a change is complete, before handing work back to the user, and any time confidence matters more than speed.
---

# Verify

Confidence requires evidence.

## When to invoke

- A fix, feature, or refactor is claimed complete.
- The user asks "does this actually work?"
- You are about to report success and need proof.
- A `critic` pass flagged insufficient verification.

## Verification order (prefer earlier steps)

1. **Existing tests.** Run the narrowest test that covers the changed behavior. If it passes, cite which test and where.
2. **Typecheck / build.** Run the project's typechecker and/or build. Cite the exact command and exit code.
3. **Narrow direct checks.** Run a CLI, a one-line script, a curl against a dev server, a `git diff --stat`, etc. -- whatever exercises the change specifically.
4. **Manual / interactive validation.** If no automation path exists, describe the exact manual steps the user should run and the observable evidence to look for.

## Rules

- Do NOT claim completion without evidence from at least one of the four steps above.
- If a check fails, include the failure verbatim (command, stderr, exit code). Do not paper over.
- If no realistic verification path exists, say so explicitly instead of bluffing.
- Prefer concise evidence summaries over noisy log dumps.
- Verify the exact behavior that was changed, not "everything still compiles" (that is necessary but not sufficient).

## Output format

```
## Verification Report

**Target**: what was supposed to be verified (one sentence)

### Evidence
- [step 1] existing test `path::test_name` -> PASS (N assertions)
- [step 2] `cargo build` -> exit 0 in 12s
- [step 3] `curl localhost:8080/health` -> 200 OK
- [step 4] manual: user should click X, expect Y

### Verdict
- VERIFIED: {list of behaviors proven}
- UNVERIFIED: {list of things we could not prove, with reason}
- FAILED: {list of things that failed verification}
```
