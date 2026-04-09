---
name: remember
description: Persist a piece of user preference, project convention, or working style to AGENTS.md so it survives future sessions. Use when the user says "remember", "from now on", "always", "never", or establishes a preference that should shape all future work in this project.
---

# Remember

Persist a preference or convention so it carries across sessions.

## When to invoke

- User says "remember", "from now on", "always do X", "never do Y", "my preference is Z".
- A working convention emerges that future sessions need to know.
- A project-wide rule is established (linter, formatter, naming convention, commit format).

## Where to persist

In this order of preference:

1. **Repo-scoped preference** -- append to `AGENTS.md` at repo root under a clearly labeled section.
2. **Global preference** (across all projects) -- append to `~/forge/AGENTS.md`.
3. **Subsystem-scoped preference** -- create or update `path/to/subsystem/AGENTS.md`.

Ask the user which scope they want if it is not obvious.

## Workflow

1. **Extract the rule.** Rewrite the user's phrasing as a single imperative sentence. "I prefer X" -> "Always X". "Don't do Y" -> "Never Y".
2. **Decide the scope.** Project-specific, global, or subsystem?
3. **Find the right section.** If `AGENTS.md` already has a "Preferences", "Conventions", "Working style", or "Rules" section, append there. Otherwise create a new section with a clear heading.
4. **Write the rule.** Keep it short. Explain the "why" only if it is non-obvious.
5. **Confirm to the user** where the rule was written and the exact text.

## Output

```markdown
Added to <AGENTS.md path> under section "<section heading>":

> <the rule as written>

This rule will apply to all future sessions in <scope>.
```

## Rules for good rules

- Imperative voice: "Always X", "Never Y", "Prefer A over B".
- Specific, not vague. "Use descriptive names" is vague. "Function names must be verbs or verb phrases; avoid get/set prefixes" is specific.
- Name the exception if one exists. "Never commit .env files except .env.example."
- Include a "why" only if the rule is counterintuitive or the rationale matters for edge cases.
- One rule per bullet. Do not bundle.

## Anti-patterns

- Adding a rule the user did not actually ask to persist (they may have just been venting).
- Duplicating an existing rule -- check before adding.
- Burying the rule in a wall of text.
- Rules that contradict existing ones without acknowledging the contradiction.

## Related

- `note` for durable context that is not a rule.
- `recall` to surface an existing rule.
- `AGENTS.md` as the canonical home for repo-scoped preferences.
