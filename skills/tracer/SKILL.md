---
name: tracer
description: Evidence-driven debugging loop. Forms multiple competing hypotheses for a bug, designs a cheap test for each, runs them in order of cheapness-first, and eliminates hypotheses with observed evidence instead of guessing. Use when a bug is reproducible but the root cause is unclear, or when a fix attempt has failed and a more rigorous approach is needed.
---

# Tracer

Rigorous, evidence-first debugging. Not "I think the bug is X" -- "here is what the evidence says the bug is".

## When to invoke

- A bug is reproducible but the root cause is unclear.
- A previous fix attempt failed or the bug came back.
- Multiple plausible causes exist and guessing is expensive.
- User says "debug this", "find the root cause", "why does this happen".

## Workflow

1. **Reproduce.** Write down the exact steps that reproduce the bug. If you cannot reproduce it, stop -- you are not ready to trace. Ask for reproduction steps.
2. **Capture the observed symptom precisely.** Exact error text, exact file:line, exact command, exact input, exact output. No paraphrasing.
3. **List competing hypotheses.** At least 3, ideally 5. Do not stop at the first plausible one. Rank by:
   - Prior probability (what usually causes this kind of symptom)
   - Cost to test (cheap hypotheses first)
4. **For each hypothesis, design a falsifying test.**
   - What single piece of evidence, if observed, would rule this hypothesis OUT?
   - What single piece of evidence, if observed, would rule this hypothesis IN?
   - Can you get that evidence with a read, a log, a debugger, a 1-line script? That is the test.
5. **Run tests cheapest-first.** Eliminate hypotheses until one survives.
6. **Confirm the surviving hypothesis.** Run one final confirming test to rule out coincidence.
7. **Write up the root cause, the fix, and the evidence trail.**

## Rules

- Never propose a fix until the root cause is confirmed by evidence.
- Every hypothesis must be falsifiable. "It might be a race condition" is not a hypothesis -- "mutex M is released before writer W finishes at path:line, causing reader R to read a torn value" is a hypothesis.
- Log every test you run and its result, even the ones that rule things out. The elimination trail is part of the evidence.
- If all hypotheses are eliminated, go back to step 3 and generate more. Do not fish.
- If the bug reproduces intermittently, capture the failing run with more logging BEFORE theorizing.

## Output

```
## Tracer Report

### Symptom
Exact observable behavior, with verbatim error / output / file:line.

### Reproduction
Exact steps.

### Hypotheses and evidence

1. **H1**: <hypothesis> 
   - Falsifying test: <cheap check>
   - Result: ELIMINATED ("evidence shows X")

2. **H2**: <hypothesis>
   - Falsifying test: <cheap check>
   - Result: ELIMINATED ("evidence shows Y")

3. **H3**: <hypothesis>
   - Falsifying test: <cheap check>
   - Result: SURVIVED
   - Confirming test: <observation>
   - Result: CONFIRMED

### Root cause
path:line -- explanation

### Fix
path:line -- what to change and why

### Verification plan
How we will prove the fix works.
```
