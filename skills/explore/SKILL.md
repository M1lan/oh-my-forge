---
name: explore
description: Structured codebase exploration before any change. Maps the architecture, identifies entry points, traces data flow, documents conventions, and produces an explorer report that orients future work. Use at the start of a new project, before a risky refactor, when onboarding to unfamiliar code, or when the request is "help me understand this codebase".
---

# Explore

Read-only, structured codebase exploration. Produces an orientation report, not code changes.

## When to invoke

- First touch on an unfamiliar codebase.
- Before a risky refactor or migration that needs a mental model.
- User says "help me understand", "walk me through", "what does this do", "where is X handled".
- Before spawning the `analyst` agent for deep architectural questions.

## Workflow

1. **Anchor the scope.** What directory? What subsystem? Do NOT try to explore the whole repo unless explicitly asked.
2. **Read the map.**
   - `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/` -- the human-authored orientation.
   - `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` -- what tooling, what language, what deps.
   - `.github/workflows/` or `.gitlab-ci.yml` -- how it gets built and tested.
3. **Find the entry points.**
   - `main.rs`, `index.ts`, `app.py`, `cmd/*/main.go`, `bin/*`, `src/main.*`.
   - For libs: `lib.rs`, `mod.rs`, `index.ts`, `__init__.py`.
   - For web apps: routes / controllers / handlers.
4. **Trace the critical path.** Pick one representative flow (login, read-a-record, render-home-page) and walk it from entry to the data layer. Note the function boundaries crossed.
5. **Document conventions.** File layout, naming, where tests live, how configuration is loaded, how errors propagate, how logging works.
6. **Note the rough edges.** TODOs, commented-out code, failing tests, outdated deps, duplicated logic. Do NOT fix them -- just note.
7. **Emit the explorer report.**

## Rules

- Read-only. No edits.
- Cite every claim with `path:line` or `path` references.
- Prefer `sem_search` for concept queries ("where is auth handled"), `fs_search` for exact strings, `read` when you know the file.
- Delegate broad "how does X work" questions to the `sage` sub-agent when available -- it is optimized for this.
- Do NOT try to map every file. Map the skeleton and one or two representative paths.

## Output

```text
## Explorer Report: <scope>

### TL;DR
One paragraph: what this codebase is, what technology, what the primary entry point is, and the one thing a newcomer must know before touching it.

### Architecture map
- Entry point: path:line
- Core modules:
  - module A (path/) -- responsibility
  - module B (path/) -- responsibility
- Data layer: path/
- Tests: path/

### Critical path walk-through
1. Request enters at path:line
2. Routed through path:line
3. Hits handler path:line
4. Reads/writes data via path:line
5. Returns through path:line

### Conventions
- file layout: ...
- naming: ...
- error handling: ...
- logging: ...
- config: ...
- tests: ...

### Gotchas / rough edges
- path:line -- description (non-blocking)
- path:line -- description

### Open questions for the user
- ...
```
