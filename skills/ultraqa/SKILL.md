---
name: ultraqa
description: Autonomous QA cycling until all tests pass
argument-hint: "<goal or acceptance criteria>"
level: 3
---

<Purpose>
UltraQA runs autonomous QA cycles until the goal is met. It repeatedly tests, diagnoses failures, and fixes until the solution is verified working.
</Purpose>

<Use_When>
- User says "ultraqa", "run QA cycles", "test until passing"
- Need to verify all edge cases
- Want automated regression testing
- Building critical path functionality
</Use_When>

<Do_Not_Use_When>
- Single quick test is sufficient
- Tests are already comprehensive
- Exploratory manual testing needed
</Do_Not_Use_When>

<QA_Cycle>
Each cycle:
1. Run tests
2. If fail: diagnose the failure
3. If fail: fix the root cause
4. Repeat until pass (max 5 cycles)

If the same failure persists 3 times:
- Flag as fundamental issue requiring human input
- Report what needs to change and why
</QA_Cycle>

<Steps>
1. **Define Goal**: What does "done" mean? List acceptance criteria
   - Present the criteria to the user
   - Ask: "I'll run QA cycles until all these pass. Correct?"
   - **CONFIRMATION REQUIRED before proceeding**

2. **Run Tests**: Execute test suite
3. **Diagnose**: If failures, identify root causes
4. **Fix**: Implement fixes for root causes
5. **Repeat**: Run tests again
6. **Verify**: Confirm all criteria met
</Steps>

<Examples>
<Good>
User: "ultraqa: verify the payment flow handles all edge cases"
Why good: Clear goal, testable criteria
</Good>

<Bad>
User: "ultraqa: make sure the app works"
Why bad: No specific criteria to verify
</Bad>
</Examples>

<Final_Output>
```
## QA Report

### Goal
[Original acceptance criteria]

### Test Results
- Tests run: N
- Passed: N
- Failed: N

### Issues Found
| Issue | Fix Applied | Status |
|-------|-------------|--------|
| ... | ... | Fixed |

### Conclusion
[Goal met / Goal not met with blockers]
```
</Final_Output>
