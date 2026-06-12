---
name: code-review
description: Structured diff review workflow that determines the review target (working tree diff, branch diff vs merge base, or specific files), delegates deep review to the code-reviewer agent and optionally security-reviewer for trust-boundary changes, produces severity-rated findings (critical/major/minor/nit) with file:line citations, verifies each critical and major finding is real before reporting, and supports an optional --fix mode that applies accepted findings. Use when code has been written and needs a quality gate, when the user says "review this", "review the diff", "code review", or "check my changes".
---

# Code Review

No approval without evidence from an independent review lane.

## When to invoke

- User says "review this", "code review", "check my changes", "review the diff", "before I merge".
- A feature or fix is complete and needs a quality gate.
- A PR description is being drafted and review findings are needed first.

## Step 1 — determine the review target

Ask once if the target is ambiguous, otherwise infer:

- **Working tree:** `shell` — `git diff HEAD` (staged + unstaged)
- **Branch vs merge base:** `shell` — `git diff $(git merge-base HEAD main)...HEAD`
- **Specific files:** read each file directly
- **Commit range:** `shell` — `git diff <ref>..<ref>`

Capture the diff output. If the diff is empty, report that and stop.

## Step 2 — classify trust boundary exposure

Before delegating, scan the diff for signals that warrant a parallel security lane:

- Auth, session, token, JWT, HMAC, cookie handling
- Input parsing from external sources (HTTP, env, file, IPC)
- Privilege escalation paths, permission checks
- Serialization / deserialization of untrusted data
- Direct shell execution, SQL construction, template rendering

If any of these are present, run the security lane in parallel with the code review lane (step 3).

## Step 3 — delegate to review agents

Use the `task` tool. Both lanes are independent; neither lane may substitute for the other.

**Code review lane** — always:

```text
task(
  agent="code-reviewer",
  prompt="CODE REVIEW LANE

Scope: <paste diff or list files>

Review for:
- Correctness: logic errors, null handling, race conditions, off-by-one, boundary cases
- Security: injection, auth bypass, XSS, CSRF, missing authZ
- Performance: N+1 queries, unnecessary allocations, blocking I/O in hot paths
- Tests: are the changed paths covered? do assertions test behavior, not implementation?
- Maintainability: duplication, naming, complexity

For each finding:
- Cite file:line
- Assign severity: Critical / Major / Minor / Nit
- Suggest a concrete fix

End with a verdict: APPROVE / REQUEST CHANGES / NEEDS DISCUSSION"
)
```

**Security lane** — when trust boundary exposure was detected in step 2:

```text
task(
  agent="security-reviewer",
  prompt="SECURITY REVIEW LANE

Scope: <paste diff or list files>

Focus only on the trust boundary exposure identified: <describe what was found in step 2>.

Run your OWASP Top 10 scan against the relevant code paths. Check for secret exposure in the diff. Produce severity-rated findings with file:line citations and concrete remediation.

Note: do NOT print any secret values into your output."
)
```

If a lane cannot be launched or returns no evidence, emit `independent review unavailable` for that lane. Do not substitute self-review for a failed lane.

## Step 4 — verify critical and major findings

Before including any Critical or Major finding in the final report, re-read the cited code at the given file:line via the `read` tool. Confirm:

1. The code at that location actually contains the described problem.
2. The problem is exploitable or produces incorrect behavior in a realistic scenario.
3. The fix suggestion is compatible with the surrounding code.

Downgrade or remove findings that do not survive this check. Pattern matching is not proof.

## Step 5 — synthesize and report

Combine both lanes. Deterministic merge gating:

- Any `Critical` finding from either lane → verdict is **REQUEST CHANGES**
- Any `Major` finding from code-reviewer → verdict is **REQUEST CHANGES**
- Security lane returned `BLOCK` → verdict is **REQUEST CHANGES**
- Security lane returned `WATCH` → verdict is **NEEDS DISCUSSION** (if code lane would APPROVE)
- No Critical/Major, no security blocker → follow code-reviewer verdict

## Step 6 — --fix mode (optional)

If the user requested `--fix`:

1. Present the findings summary and ask which severities to fix (default: Critical and Major only).
2. For each accepted finding, apply the fix via `patch` or `write`.
3. After all fixes, re-run the narrowest test suite via `shell` to confirm nothing regressed.
4. Report what was changed and what remains for the user to address manually.

## Output format

```text
## Code Review Report

### Scope
<files reviewed, what the diff claims to do>

### Critical (blocks merge)
- **`path/to/file.ext:LL`** — <what is wrong>
  Fix: <specific suggestion>

### Major (should fix before merge)
- **`path/to/file.ext:LL`** — <what is wrong>
  Fix: <suggestion>

### Minor (consider addressing)
- **`path/to/file.ext:LL`** — <observation>
  Suggestion: <optional improvement>

### Nit (pick up if convenient)
- **`path/to/file.ext:LL`** — <style or naming note>

### Security findings
<from security lane, or "security lane not triggered" / "security lane unavailable">

### What went well
- <specific thing done correctly — not "code is clean", but "correct use of X">

### Summary
- Files reviewed: N
- Findings: C critical, M major, m minor, N nits
- Security lane: triggered / not triggered / unavailable
- Verdict: **APPROVE** / **REQUEST CHANGES** / **NEEDS DISCUSSION**
```

## Rules

- Never self-approve. If both lanes are unavailable, report that and block.
- Re-read every Critical and Major finding before reporting (step 4 is not optional).
- Never print secret values that appear in the diff or codebase.
- Cite `file:line` for every finding. "Around the auth module" is not a citation.
- Pair every criticism with a concrete fix suggestion.
- Include at least one observation about what was done well.
- When using git to get the diff, use `shell` with `git diff` — follow the Lore commit protocol for any commits suggested to the user.
