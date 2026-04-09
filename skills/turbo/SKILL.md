---
name: turbo
description: Maximum-throughput parallel execution mode. Bypasses interactive confirmation loops, groups related operations, executes independent work in parallel, and favors speed over narration. Use when the user says "turbo", "just do it", "no confirmations", or otherwise signals they want the full change made now without stopping.
---

# Turbo Mode

> "Everything at maximum speed. I'll write all the code now."

## When to Use

Use when you need maximum parallel execution with minimal overhead. The assistant operates in a fully autonomous, high-throughput mode.

**Trigger**: `turbo` or `turbo:` prefix

## How It Works

Turbo mode bypasses interactive confirmation loops and executes tasks in parallel streams. This is the fastest way to get things done when you know exactly what you want.

## Rules

1. **Parallel Execution**: Execute independent tasks simultaneously across files
2. **No Confirmation**: Skip the "Should I proceed?" prompts
3. **Batch Operations**: Group related operations (e.g., create all missing files at once)
4. **Speed Over Explanation**: Minimal narration, maximum output
5. **Immediate Feedback**: Show progress as things complete

## Execution Flow

```text
turbo: build a login page

→ Understand task (fast)
→ Identify all files to create/modify
→ Execute in parallel
→ Report completion
```

## Anti-Patterns (Do NOT)

- ❌ Stop for confirmation after each file
- ❌ Ask "Are you sure?" repeatedly
- ❌ Write verbose explanations
- ❌ Execute serially when parallel is possible

## Example

```text
❯ turbo: add user profile component to all pages

[PARALLEL]
→ Created components/UserProfile.tsx
→ Updated pages/Home.tsx
→ Updated pages/Dashboard.tsx
→ Updated pages/Settings.tsx
→ Updated routes/index.tsx

Done. 5 files modified in 12s.
```

## Skill File Format

For a project-specific turbo configuration:

```text
skills/turbo/
└── CONFIG.md    # Optional: define turbo rules for this project
```

## Related Modes

| Mode | Speed | Confirmation | Use Case |
|------|-------|--------------|----------|
| `turbo` | Fastest | None | Known tasks, rapid execution |
| `autopilot` | Fast | Minimal | Complex tasks needing oversight |
| `eco` | Slow | Moderate | Resource-constrained environments |
