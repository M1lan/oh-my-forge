---
name: team
description: Coordinate multi-agent parallel work on a task. Splits work across specialists and integrates results.
---

Coordinate a team on: {{parameters}}

Load the `team` skill and follow its workflow.

Workflow:

1. **Decompose** the task into independent subtasks
2. **Assign** each subtask to the most appropriate specialist agent
3. **Launch** agents in parallel (use the `task` tool with multiple invocations in one message)
4. **Integrate** the results -- resolve conflicts, merge artifacts
5. **Verify** the integrated result with the `verifier` agent

Output: a coordination report showing which agents did what, with links to their outputs.
