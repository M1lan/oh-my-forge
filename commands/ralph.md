---
name: ralph
description: Persistence mode -- keep working until the task is verifiably complete. For tasks that need multiple attempts.
---

Ralph mode on: {{parameters}}

Load the `ralph` skill and follow its workflow.

Persistence loop:
1. Attempt the task
2. Verify with the `verifier` agent
3. If NOT DONE, analyze why, adjust, and try again
4. Repeat until DONE or you hit a Ground Truth contradiction

Don't give up until:
- The task is verifiably complete, OR
- You encounter a Ground Truth contradiction (then stop and ask), OR
- You've exhausted reasonable alternatives and need human judgment

Track attempt count and what changed between attempts.
