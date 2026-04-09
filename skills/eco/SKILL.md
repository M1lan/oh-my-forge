---
name: eco
description: Lightweight execution mode for simple, well-defined tasks. Skips elaborate planning, avoids spawning sub-agents, keeps context lean, and makes direct precise edits. Use when the user asks for a small fix, a single-file change, a rename, or a quick tweak and explicitly wants minimal ceremony.
---

# Eco Mode

> "Lightweight mode for simple tasks and constrained environments."

## When to Use

Use for simple, well-defined tasks where full agent orchestration is overkill. Eco prioritizes minimal resource usage and straightforward execution.

**Trigger**: `eco:` or `simple:` or `quick:` prefix

## How It Works

Eco mode is a lightweight execution mode that:

- Skips complex planning phases
- Uses direct, minimal steps
- Avoids spawning sub-agents
- Keeps context window lean

## Rules

1. **Simple First**: If the task can be done in one step, do it in one step
2. **Minimal Context**: Don't load additional skills unless explicitly needed
3. **Direct Execution**: No planning loop, just do it
4. **Small Changes**: Ideal for edits, small features, bug fixes
5. **Single File Focus**: Don't expand scope to related files

## Execution Flow

```text
eco: fix the login button style

→ Read current file
→ Identify the issue
→ Make precise edit
→ Done
```

## Anti-Patterns (Do NOT)

- ❌ Use for complex multi-file projects
- ❌ Spawn multiple agents
- ❌ Create elaborate plans
- ❌ Expand scope beyond the request

## Good Use Cases

- Fix a specific CSS bug
- Rename a variable across files
- Add a single prop to a component
- Update documentation for one file
- Simple refactoring (rename function, extract constant)

## Bad Use Cases

- Building an entire application
- Complex migrations
- Multi-system integrations
- Anything requiring architectural decisions

## Example

```text
❯ eco: change the primary color from blue to green

→ Read styles/theme.css
→ Changed #3b82f6 to #22c55e (1 occurrence)
→ Done. 1 file modified.
```

## Comparison

| Mode | Complexity | Scope | Confirmation |
|------|------------|-------|--------------|
| `eco` | Low | Single/minor | None |
| `turbo` | Medium | Full | None |
| `autopilot` | High | Full | Minimal |
| `plan` | Any | Plan only | Extensive |

## Related Modes

| Mode | Speed | Confirmation | Use Case |
|------|-------|--------------|----------|
| `eco` | Fast | None | Simple tasks |
| `turbo` | Fastest | None | Known tasks |
| `autopilot` | Fast | Minimal | Complex tasks |
| `plan` | Slow | Extensive | Unknown scope |
