---
name: ralph
description: Persistence mode — doesn't stop until the task is verified complete
---

<Purpose>
Ralph enforces completion — it doesn't stop until the task is verified working. Unlike normal execution which gives up when the first attempt fails or context runs out, Ralph cycles through fix loops until the goal is achieved and validated.
</Purpose>

<Use_When>
- User says "ralph", "don't stop", "must complete", "until done", "don't give up"
- Task MUST complete regardless of setbacks
- User wants verification that the fix actually worked
- Important bug fixes or feature implementations that can't be left half-done
</Use_When>

<Do_Not_Use_When>
- Quick exploratory tasks where partial completion is fine
- Tasks that require human decision-making at each step
- Research tasks without a clear completion criteria
</Do_Not_Use_When>

<Execution_Policy>
- Don't stop on errors — fix and retry
- Don't stop on test failures — debug and fix
- Don't stop on partial completion — verify fully done
- If fundamentally stuck after 3 retries, report the blocker clearly
</Execution_Policy>

<Steps>
1. **Clarify Goal**: What is the end goal? What does "done" look like?
   - Ask the user to confirm: "I'll keep going until [X] is verified working. Is that correct?"
   - If goal is unclear, ask one question at a time until it's specific and verifiable
   - **CONFIRMATION REQUIRED before proceeding**

2. **Execute**: Implement the solution
3. **Test**: Run tests to verify
4. **Fix**: If tests fail, diagnose and fix
5. **Repeat**: Steps 3-4 until all tests pass
6. **Verify**: Confirm the original problem is resolved
   - Show the user proof that the goal was achieved

<Loop_Behavior>
The ralph loop continues until:
- All tests pass
- The user explicitly stops
- The same fundamental issue blocks progress 3 times

When blocked: Report the blocker with specific details, suggest options
</Loop_Behavior>

<Examples>
<Good>
User: "ralph: fix all TypeScript errors in the auth module"
Why good: Clear scope, verifiable output (no TypeScript errors)
</Good>

<Good>
User: "don't stop: migrate the user table to use UUIDs"
Why good: Clear scope, can verify migration worked
</Good>

<Bad>
User: "ralph: research best practices for caching"
Why bad: Research has no clear completion criteria
</Bad>
</Examples>
