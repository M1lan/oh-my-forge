---
name: use-grepai
description: "Semantic code search via the `grepai` CLI. Load this skill when working on any codebase that has a `.grepai/` directory, when you need to find code by intent rather than exact text, when you need a call graph (who-calls-what) or property-usage graph (readers/writers) that `rg` and `sem_search` cannot produce, or when the user asks about grepai. Complementary to (not a replacement for) `rg` (exact text), `sem_search` (Forge built-in, `~/forge` only), and the project-wide `.grepai/` index."
---

# `grepai` — Semantic Code Search for Any Codebase

`grepai` is a privacy-first, local-first semantic code search CLI. It indexes
your code with vector embeddings via a background watcher and exposes the
index through a `search`, `trace`, and `refs` CLI. Think "grep, but the
index understands meaning, call graphs, and property reads/writes."

Source: `~/mysrc/grepai/` · Binary: `grepai` (installed in `PATH`) ·
Version on this machine: `0.1.0`.

## When to reach for `grepai`

**Reach for it when ANY of these are true:**

1. The project root (or an ancestor) contains a `.grepai/` directory — the
   index already exists, use it.
2. You are working **outside** `~/forge/` and need conceptual / intent-based
   search (`sem_search` is hard-scoped to `/Users/milan.santosi/forge` and
   below — it cannot help you in `~/mysrc/*`, sibling projects, or any
   client repo).
3. You need a **call graph** — "who calls `Foo`?", "what does `Foo` call?",
   "give me a 3-deep graph around `Foo`". Neither `rg` nor `sem_search`
   produce this.
4. You need a **property usage graph** — "where is `store.uid` read?",
   "who writes to `currentUser`?". Same as above: only `grepai refs` does
   this.
5. The user mentions "grepai", "semantic search", "index this project",
   "the watcher", or asks for call/property tracing.

**Do NOT reach for it when:**

- You need exact text matching (literals, imports, error strings, TODOs).
  Use `rg` — it is faster and exact.
- You are inside `~/forge/` and want semantic search on Forge's own code.
  Use `sem_search` — it is already running and indexed.
- The project has no `.grepai/` AND indexing it is out of scope for the
  current task. Don't auto-index a stranger's repo without the user asking.
- The watcher daemon is not running and the user wants a one-off question
  answered right now. Either ask permission to start it or fall back to
  `rg` / `sem_search`.

## Detection sequence (do this every time you start work on a new repo)

```bash
# 1. Is the project indexed?
test -d .grepai && echo "indexed" || echo "not indexed"

# 2. Is the watcher running?
grepai watch --status      # → "Status: running" or "Status: not running"

# 3. What's the index health?
grepai status --no-ui      # plain-text summary; --ui for TUI
```

If indexed + running → just `grepai search "..."`. If indexed but watcher
not running → propose `grepai watch --background`. If not indexed → ask the
user whether to `grepai init` (it's a one-time choice that pins the
embedding provider; see the Bootstrap section below).

## Decision matrix — `grepai` vs `rg` vs `sem_search`

| Need | Use |
|------|-----|
| Find by intent / concept ("authentication flow") in **any** repo with `.grepai/` | `grepai search` |
| Find by intent / concept inside `~/forge/` (Forge codebase itself) | `sem_search` (built-in) |
| Find an exact string / regex / identifier / import path | `rg` (per the `use-rg` skill) |
| List callers / callees / call graph | `grepai trace callers|callees|graph` |
| List property readers / writers (non-call data flow) | `grepai refs readers|writers|graph` |
| Cross-project search over multiple repos | `grepai search --workspace <name>` |

Rule of thumb: **`rg` for tokens, `grepai` for meaning, `sem_search` only
inside `~/forge/`.** They are complements, not competitors.

## Core commands

All commands accept `--json` (or `--toon` for ~30% fewer tokens than JSON)
for agent consumption, and `--compact` to drop the code preview body
(~80% token reduction; pair with `--json`/`--toon`).

### `grepai search` — semantic search

```bash
# Default: top 10 results, rich text output
grepai search "user authentication flow"

# Agent-friendly: TOON output, no preview body, 15 results
grepai search "JWT token validation" --toon --compact -n 15

# Restrict by path prefix
grepai search "rate limiting" --path internal/middleware --json

# Cross-project search (requires a configured workspace)
grepai search "session expiry" --workspace mywork --project api --project worker --json
```

Query tips:

- **English, intent-shaped**: "handles user login", not `func Login`.
- **Be specific**: "JWT refresh-token rotation" beats "token".
- **Multiple varied queries** beat one broad query — run 2–3 in parallel,
  each capturing a different angle. (Same principle as `sem_search`.)

### `grepai trace` — call graph

```bash
# Who calls Foo?
grepai trace callers "ProcessOrder" --json

# What does Foo call?
grepai trace callees "ProcessOrder" --json

# Full graph, depth 3
grepai trace graph "ValidateToken" --depth 3 --json

# Modes: --mode fast (regex, default) or --mode precise (tree-sitter)
grepai trace callers "Login" --mode precise --json
```

Use **before** modifying a function whose blast radius you don't know.
Use **after** finding a candidate symbol with `grepai search` to expand
context.

### `grepai refs` — property / data usage graph

```bash
# Where is the property read?
grepai refs readers "uid" --json

# Where is it written?
grepai refs writers "uid" --json

# Both, in graph form
grepai refs graph "currentUser" --json
```

Use this when the target is **state / a field / a config key**, not a
callable. Example: tracing `store.uid` through a React app, or
`config.DatabaseURL` through a Go service.

## Bootstrap a fresh project (only when the user asks)

```bash
# 1. Pick provider + backend interactively
grepai init

# Or non-interactive defaults (Ollama + GOB file backend)
grepai init --yes

# Provider/backend can be set explicitly
grepai init --provider ollama --model nomic-embed-text --backend gob --yes
grepai init --provider openai --model text-embedding-3-small --backend gob --yes

# 2. Start the watcher (background — recommended)
grepai watch --background

# 3. Confirm
grepai watch --status
grepai status --no-ui
```

The default local provider is Ollama with `nomic-embed-text` (requires
`ollama pull nomic-embed-text`). LM Studio, OpenAI, OpenRouter, and a
`synthetic` (dev/test) provider are also available — see `grepai init -h`.

Backends: `gob` (single-file, default, no infra), `postgres` (pgvector),
`qdrant`. Workspaces (`grepai workspace`) require `postgres` or `qdrant`
because GOB is per-project.

`.grepai/` is auto-added to `.gitignore` by `grepai init`. Do not commit
it.

## MCP server (optional — not needed when invoking via shell)

`grepai mcp-serve` exposes 11 tools over MCP (`grepai_search`,
`grepai_trace_callers/callees/graph`, `grepai_refs_readers/writers/graph`,
`grepai_index_status`, `grepai_rpg_*`). You do **not** need this when
running grepai via `shell` — these notes are for the case where the user
wires grepai into Claude Code / Cursor / another MCP client. Wiring is
out of scope for this skill; refer the user to `grepai mcp-serve --help`.

## Token-efficiency cheat sheet

Always pass these for agent calls — the input-token savings are real:

| Flag | Effect |
|------|--------|
| `--json` | Machine-readable structure |
| `--toon` | ~30% smaller than `--json`, still structured |
| `--compact` | Drop code preview body (~80% smaller; pair with `--json`/`--toon`) |
| `-n 5` / `-n 15` | Cap result count — start small, widen if needed |
| `--path <prefix>` | Pre-filter by directory before re-ranking |

Pattern: start narrow (`--toon --compact -n 5 --path <hot-dir>`); widen
only if the first pass misses.

## Common pitfalls

- **Stale index**: if the watcher is not running, results are frozen at
  the last scan. Check `grepai watch --status` first.
- **Wrong embedding scope**: queries are embedded with the project's
  configured provider/model — if a user switches model mid-project, the
  vector space changes and recall degrades. Re-index by deleting the
  store and re-running the watcher.
- **GOB + workspaces**: GOB cannot be used for multi-project workspaces.
  `grepai workspace create` requires Postgres or Qdrant.
- **The repo's own AGENTS.md / CLAUDE.md may already mention grepai**:
  some projects have run `grepai agent-setup`. If you find a `## grepai
  - Semantic Code Search` section in the project's `AGENTS.md`, treat
  the project as a confirmed grepai project — the user has already
  opted in.
- **Don't write inside `.grepai/`**: it's a generated index store,
  not a source directory. Treat it like `.git/`.

## Related skills

- `use-rg` — exact text search (`rg`, never `grep`).
- `use-fd` — file discovery (`fd`, never `find`).
- `use-mempalace` — long-term memory of past conversations and notes.
  Complementary: mempalace remembers *what we discussed about code*;
  grepai indexes *the code itself*.

## Source of truth

- Binary: `grepai` in `PATH`. `grepai version` to confirm.
- Local clone: `~/mysrc/grepai/` — read `README.md`, `CLAUDE.md`, and
  `cli/*.go` for ground truth on flags and behaviour.
- `grepai <command> --help` is authoritative for flags; this skill may
  lag behind on newly added flags.
