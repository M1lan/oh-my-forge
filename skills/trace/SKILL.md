---
name: trace
description: Evidence-driven debugging with parallel hypothesis testing
argument-hint: "<bug or error description>"
level: 3
---

<Purpose>
Trace systematically debugs issues using evidence-driven hypothesis testing. Instead of guessing, it forms theories and tests them against the evidence (error messages, logs, code).
</Purpose>

<Use_When>
- User says "trace", "debug", "hunt this bug"
- Complex bug with unclear root cause
- Intermittent issues
- Error that has multiple possible explanations
</Use_When>

<Do_Not_Use_When>
- Obvious bugs with clear error messages
- Simple typos or syntax errors
- Issues already diagnosed
</Do_Not_Use_When>

<Debugging_Protocol>
### Step 1: Gather Evidence
- Error messages (exact text)
- Stack traces
- Logs
- Reproduction steps
- Environment context

### Step 2: Form Hypotheses
List all possible explanations for the bug.
Example: "Login fails"
- Hypothesis A: Database connection issue
- Hypothesis B: Wrong password hash algorithm
- Hypothesis C: Session middleware misconfigured
- Hypothesis D: CSRF token validation failing

### Step 3: Test Hypotheses
For each hypothesis, determine what evidence would confirm or refute it.
Then gather that evidence by reading the relevant code.

### Step 4: Isolate Root Cause
The hypothesis with the most supporting evidence and no refutation is the root cause.

### Step 5: Fix
Implement the minimal fix that addresses the root cause.

### Step 6: Verify
Confirm the original symptom is resolved.
</Debugging_Protocol>

<Output_Format>
```
## Bug Trace Report

### Evidence
- [Collected error messages, logs, context]

### Hypotheses
| Hypothesis | Evidence For | Evidence Against |
|-----------|--------------|-----------------|
| A: ... | ... | ... |
| B: ... | ... | ... |

### Root Cause
[Identified root cause with explanation]

### Fix
[Code change]

### Verification
[Test showing fix works]
```
</Output_Format>

<Examples>
<Good>
User: "trace: API returns 500 only on production, works fine locally"
Why good: Specific symptom, environment difference hints at config issue
</Good>

<Bad>
User: "trace: this code doesn't work"
Why bad: No evidence, no symptom description
</Bad>
</Examples>
