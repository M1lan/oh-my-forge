---
name: ultrawork
description: Maximum parallel throughput — execute independent tasks simultaneously
argument-hint: "<task with multiple independent subtasks>"
level: 3
---

<Purpose>
Ultrawork maximizes parallel execution by decomposing tasks into independent subtasks and running them concurrently. Use when you have multiple parallel workstreams that don't depend on each other.
</Purpose>

<Use_When>
- User says "ultrawork", "ulw", "parallel", "run in parallel"
- Task has multiple independent subtasks
- User wants maximum throughput
- "Fix all errors" across multiple files
</Use_When>

<Do_Not_Use_When>
- Tasks have strict sequential dependencies
- Single focused task with no parallelization opportunity
- Tasks requiring shared state between steps
</Do_Not_Use_When>

<Execution_Policy>
- Decompose into truly independent subtasks
- Execute independent tasks in parallel
- Each subtask gets its own implementation cycle
- Aggregate results at the end
</Execution_Policy>

<Steps>
1. **Decompose**: Break the task into N independent subtasks
2. **Show Subtasks**: List the subtasks to the user
   - Ask: "I'll run these N tasks in parallel. Any dependencies I missed?"
   - **CONFIRMATION REQUIRED before proceeding**
3. **Execute**: Run all subtasks in parallel
4. **Aggregate**: Collect and combine results
5. **Verify**: Run full test suite to confirm nothing broke

<Parallel_Tasks_Example>
Task: "Fix all ESLint errors across the codebase"
Subtasks:
- Fix ESLint errors in src/components/
- Fix ESLint errors in src/utils/
- Fix ESLint errors in src/hooks/
These run in parallel.
</Parallel_Tasks_Example>

<Examples>
<Good>
User: "ultrawork fix all TypeScript errors across the project"
Why good: Multiple files can be fixed in parallel
</Good>

<Bad>
User: "ultrawork implement user authentication"
Why bad: Auth has sequential dependencies (DB schema → models → routes → UI)
</Bad>
</Examples>
