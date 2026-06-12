---
name: tdd
description: "Red-green-refactor discipline for forge. Write a failing test first, run it via shell to confirm RED, implement the minimum production code to reach GREEN, confirm GREEN via shell, refactor with tests staying green, then repeat for the next behavior. Delegates test authoring to the test-writer agent when the test structure is non-trivial. Enforces the Iron Law: no production code without a failing test first. Use when the user says 'TDD', 'test-first', 'red-green-refactor', 'write the test first', or 'I want to do TDD'."
---

# TDD

The Iron Law: no production code without a failing test first.

## When to invoke

- User says "TDD", "test-first", "red-green-refactor", "write the test before the code".
- A new feature or behavior is about to be implemented and the user wants test-first discipline.
- A bug needs a regression test written before the fix.

## The cycle

Each behavior gets its own complete cycle before the next one starts.

### Phase 1 — RED

1. Identify the single next behavior to implement. Name it precisely: "returns 401 when token is expired", not "handles auth".
2. Write a test that asserts that behavior. Options:
   - Write it directly if the test structure is obvious and follows existing conventions.
   - Delegate to `test-writer` when the test requires non-trivial setup (fixtures, factories, database state, mock infrastructure):

```text
task(
  agent="test-writer",
  prompt="Write ONE failing test for this behavior: <behavior name>

Code under test (or location): <file or snippet>
Existing test conventions: <test file to mirror, or 'discover via sem_search'>

The test must:
- Follow the project's existing test structure and naming
- Assert the specific behavior, not implementation details
- Be deterministic (no sleeps, no unfrozen dates, no network)
- Fail right now because the production code does not yet implement the behavior

Do not write the production code. Write only the test."
)
```

3. Run the test suite via `shell` using the narrowest command that covers the new test. Confirm it **fails** with a meaningful message, not an error unrelated to the missing behavior (e.g., import failure or syntax error means the test itself is broken — fix it first).

If the test passes on the first run, the test is wrong. It must fail. Fix the test before proceeding.

### Phase 2 — GREEN

4. Implement the minimum production code to make the failing test pass. Nothing more.
   - No "while I'm here" additions.
   - No speculative handling for behaviors not yet tested.
   - Hardcoding a return value to pass the test is acceptable if it is the minimal correct step — the next cycle will force generalization.

5. Run the same test command via `shell`. Confirm:
   - The new test **passes**.
   - All previously passing tests **still pass**.

If other tests broke, fix the regression before moving forward. Do not weaken assertions to make a test pass.

### Phase 3 — REFACTOR

6. Improve the code quality without changing behavior:
   - Remove duplication.
   - Improve naming.
   - Simplify logic.
   - Extract a function if a unit is doing two things.

7. After every refactor change, run the tests via `shell`. They must stay green. If they go red, the refactor introduced a regression — revert and try a smaller step.

8. When the code is clean and tests are green, the cycle is complete.

### Repeat

Go to Phase 1 for the next behavior.

## Choosing the test command

Prefer the narrowest command that covers the test being added:

- Single test file: `<runner> path/to/test_file`
- Single test by name: `<runner> -k "test_name"` or `<runner> --testNamePattern "..."`
- Module-level suite: `<runner> path/to/module/`
- Full suite: only when the behavior touches cross-module paths

Running the full suite on every cycle is acceptable for small projects. For larger projects it adds friction to the discipline — narrow it down.

## Output format per cycle

```text
## TDD Cycle: <behavior name>

### RED
Test: <file:line where the test was written>
Run: <exact command>
Result: FAIL — <failure message, abbreviated>

### GREEN
Implementation: <file:line where production code was added>
Run: <exact command>
Result: PASS — <N tests passed>

### REFACTOR
Changes: <what was cleaned up, or "no refactor needed">
Run: <exact command>
Result: PASS — <N tests passed>

Next behavior: <what the next cycle will cover, or "scope complete">
```

## Rules

- Never write production code before the test exists and is confirmed RED.
- Never weaken test assertions to make a test pass. Fix the production code instead.
- Never skip the refactor phase because "it looks fine". If there is nothing to clean up, say so explicitly.
- One behavior per cycle. Do not batch multiple behaviors into one test.
- If the test passes without any production code change, the test does not prove the behavior — fix the test.
- If the suite is slow, narrow the test command rather than skipping the RED confirmation.
- For bug fixes: write a test that reproduces the bug (RED), then fix the bug (GREEN). The test is the regression guard.
