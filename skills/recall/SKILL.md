---
name: recall
description: Find prior context from docs/notes/, plans/, docs/adr/, and git history. Searches across captured notes, past plans, and commit messages to answer "have we seen this before?" or "what did we decide about X?". Use when the user references an earlier decision, asks about history, or when a new question feels familiar.
---

# Recall

Retrieve prior context so you don't reinvent decisions already made.

## When to invoke

- User says "have we done this before", "what did we decide about X", "did we already discuss this", "remember when".
- A design question arises that feels familiar.
- Before proposing a new approach, check whether the team already has one.
- Before writing a new `note` or `adr`, check for an existing one on the same topic.

## Search scope

In order of preference:

1. **`docs/notes/`** -- durable notes captured via the `note` skill.
2. **`docs/adr/`** -- architectural decision records.
3. **`plans/`** -- past plan files from the plan/ralplan skills.
4. **`docs/gotchas.md`** and other docs -- longform context.
5. **`git log --all --oneline` and `git log --grep`** -- commit history.
6. **`CHANGELOG.md`** -- release notes.

## Workflow

1. **Extract keywords.** From the user's question, pull 2-4 concrete terms (feature name, file, component, decision topic). Avoid generic words like "system", "user", "feature".
2. **Search notes first.** `fs_search` for keywords in `docs/notes/`, `docs/adr/`, `plans/`.
3. **Search git history.** `git log --all --oneline --grep='<keyword>'` and `git log --all --oneline -S'<symbol>'` (the latter finds commits where the symbol appears in the diff).
4. **Read the most relevant hits.** Limit to top 3-5 to avoid context bloat.
5. **Synthesize.** Answer the user's question with citations.

## Rules

- Always cite with `path:line` or `git-sha:subject`.
- If nothing is found, say so -- do not invent context.
- If multiple prior decisions conflict, surface that explicitly.
- If the user's question implies a decision was made but nothing exists, suggest they capture it now with the `note` or `adr` skill.

## Output

```
## Recall Result: <topic>

### Found
1. docs/notes/2026-03-15-auth-token-rotation.md -- "We chose refresh tokens over sliding sessions because..."
2. plans/2026-02-01-auth-redesign-v2.md -- the full plan that produced the above decision
3. git 3f7a9d2 -- "auth: switch to refresh tokens" -- 2026-03-17

### Relevant excerpt
> ...

### Answer
Based on the notes, <answer>. See path:line for the original rationale.
```

If nothing is found:

```
## Recall Result: <topic>

No prior notes, ADRs, plans, or commits found for <keywords>.
Suggest capturing the current decision with the `note` or `adr` skill.
```
