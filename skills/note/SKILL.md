---
name: note
description: Capture a durable note during a working session -- design decisions, gotchas, "why we did this", open questions, or followups. Writes to docs/notes/YYYY-MM-DD-<slug>.md by default. Use when the user says "note this", "remember this", "capture that", "write this down", or when encountering something worth preserving beyond this session.
---

# Note

Capture durable context so it survives the end of the current session.

## When to invoke

- User says "note this", "remember this", "write this down", "capture this".
- You encounter a non-obvious decision, workaround, or gotcha worth preserving.
- A followup emerges that is out of scope for the current task.
- A design choice has a non-obvious rationale that future readers will need.

## Where notes go

Default: `docs/notes/YYYY-MM-DD-<slug>.md`

Alternate targets (pick based on the note type):

- Architectural decision -> `docs/adr/YYYY-MM-DD-<slug>.md`
- Followup task -> append to `TODO.md` at repo root
- Gotcha for future sessions -> `docs/gotchas.md`

If no `docs/notes/` directory exists, create it (but only if the note is actually durable -- not for one-off scratch).

## Note template

```markdown
# <Title>

**Date**: YYYY-MM-DD
**Context**: project/subsystem where this came up
**Status**: active | resolved | superseded

## What

One paragraph: what is the note about.

## Why it matters

What did we learn, or what will a future reader need?

## References

- path:line
- path:line
- Related PR / issue / commit
```

## Rules

- Keep notes short. A note is not a tutorial.
- Always include a date and context.
- Cite source with `path:line` references where relevant.
- Prefer appending to an existing notes file if one exists for the same topic.
- Do NOT create `docs/notes/` unless the note is truly worth persisting.
- Ask the user before creating a new ADR -- those are heavier-weight and benefit from a consistent template.

## Output

Tell the user:

1. Where the note was written (exact path).
2. What was captured (one-line summary).
3. Whether a new directory was created.
