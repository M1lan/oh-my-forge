---
name: cancel
description: Gracefully stop a long-running or autonomous workflow (autopilot, ralph, team, turbo, ultrawork). Reports current phase, asks for confirmation if work is mid-flight, and cleans up in-progress state without discarding completed work. Use when the user says "cancel", "stop", "abort", or when an autonomous loop needs a safe exit.
---

# Cancel

Safe, graceful exit from autonomous or long-running work.

## When to invoke

- User says "cancel", "stop", "abort", "stop that", "never mind".
- An autopilot, ralph, team, or ultrawork loop needs to halt.
- The current task has become wrong or irrelevant and should not continue.
- Mid-iteration on a plan when the plan itself is flawed.

## Workflow

1. **Identify what is active.** Look at the current todo list (`todo_read`) and any in-flight skill or agent invocation. Name them explicitly.
2. **Report current state.** Tell the user:
   - What was the goal.
   - What was completed so far (specific files, tasks, artifacts).
   - What was in progress at the moment of cancel.
   - What was not yet started.
3. **Confirm if destructive.** If the cancel would discard uncommitted work, ask once: "You have {N} uncommitted changes in {files}. Cancel anyway? (y/N)". For read-only or purely planning workflows, skip the prompt.
4. **Clean up.**
   - Mark all `in_progress` todos as `cancelled` (not `completed`).
   - If the active workflow wrote a partial artifact (draft plan, scratch file), leave it on disk with a clear marker and tell the user where.
   - Do NOT delete completed work.
5. **Emit cancel report.**

## Rules

- NEVER mark a task `completed` during cancel. Use `cancelled`.
- NEVER silently roll back committed work.
- Always tell the user exactly what was preserved and what was dropped.
- If cancel is ambiguous ("stop" could mean this turn or the whole task), ask.
- If cancel happens mid-edit, the partial edit stays -- the user can `undo` it manually if they want.

## Output

```
## Cancel Report

**Cancelled**: {workflow name, e.g. "autopilot: add user auth"}
**Reason**: {user request / error / scope change}

### Completed before cancel
- [x] file1.ts -- updated import
- [x] tests/auth.test.ts -- added 2 cases

### In progress at cancel (now cancelled)
- [!] migration script -- partial, saved to scripts/migrate-auth.draft.sh
- [!] auth middleware -- not yet written

### Not started
- [ ] docs update
- [ ] deployment config

### Uncommitted changes
- src/auth.ts (modified)
- src/middleware/auth.ts (new, untracked)

### Next step suggestion
Review changes with `git status && git diff`, then either commit or undo.
```
