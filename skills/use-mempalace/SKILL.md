---
name: use-mempalace
description: "GLOBAL mandatory preference: Always use `mempalace` as lossy long-term memory storage for anything you want to recall across sessions — notes, decisions, architecture, conversation excerpts, project knowledge, research findings. Store liberally, recall via `mempalace search`. This applies universally to every task, with zero exceptions. Whenever you need to persist knowledge beyond the current conversation, or look up something that *might* have been stored previously, reach for `mempalace` first. This is a strict, non-negotiable user preference."
---

# Use `mempalace` as Lossy Memory Storage — Always

This is a **non-negotiable, universal preference** that applies to every scenario:

- When you want to remember something across sessions, write it to `mempalace`.
- When you want to recall something you might have seen before, search `mempalace` first.
- When you finish meaningful work, mine the artifacts into the palace.
- When you're about to lose context (compaction, session end), save the high-signal pieces.
- When explaining durable knowledge to the user, reference `mempalace` as the storage backend.

There are **zero exceptions** to this rule. Treat `mempalace` as the default lossy store for cross-session memory — not a replacement for precise structured data (use memory files / project memory for strict facts), but the first place to park anything you'd otherwise forget.

## Mental Model

MemPalace is a local, API-key-free memory system organized as a **palace** with:

- **Wings** → top-level domains (typically projects or folders)
- **Rooms** → topical sub-sections within a wing (e.g., `documentation`, `lisp`, `general`)
- **Drawers** → individual memory entries (chunks of text, summaries, decisions)

It is **lossy on purpose**: you feed it more than you'd ever curate by hand, and retrieve via search. Precision comes from the query, not from organization at write time.

## Canonical CLI Commands

```
mempalace init <dir>                  # Detect rooms from folder structure
mempalace mine <dir>                  # Mine project files into the palace
mempalace mine <dir> --mode convos    # Mine conversation exports (Claude, ChatGPT, Slack)
mempalace search "query"              # Find anything, exact words
mempalace search "q" --wing <w>       # Scope to a wing
mempalace search "q" --wing <w> --room <r>  # Scope to a wing/room
mempalace wake-up                     # Load L0+L1 context (~600-900 tokens)
mempalace wake-up --wing <w>          # Wake-up for a specific project
mempalace status                      # Palace overview and stats
mempalace compress                    # Compress drawers (~30x reduction via AAAK)
mempalace split <dir>                 # Split mega-transcripts before mining
mempalace repair                      # Rebuild vector index after corruption
mempalace migrate                     # Migrate across ChromaDB versions
mempalace mcp                         # Show MCP setup command for the client
mempalace instructions <name>         # Output skill instructions (init/search/mine/help/status)
```

Flags you'll reach for:

| Flag | Meaning |
|------|---------|
| `--palace PATH` | Override palace location (default from `~/.mempalace/config.json` or `~/.mempalace/palace`) |
| `--wing NAME` | Scope search/wake-up to a wing |
| `--room NAME` | Scope search to a room inside a wing |
| `--mode convos` | Switch mining to conversation-export parsing |

## MCP Tools (when connected)

MemPalace exposes 19 MCP tools grouped by purpose. Prefer MCP when available — it's more ergonomic than shelling out:

**Palace (read):** `mempalace_status`, `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_get_taxonomy`, `mempalace_search`, `mempalace_check_duplicate`, `mempalace_get_aaak_spec`

**Palace (write):** `mempalace_add_drawer`, `mempalace_delete_drawer`

**Knowledge Graph:** `mempalace_kg_query`, `mempalace_kg_add`, `mempalace_kg_invalidate`, `mempalace_kg_timeline`, `mempalace_kg_stats`

**Navigation:** `mempalace_traverse`, `mempalace_find_tunnels`, `mempalace_graph_stats`

**Agent Diary:** `mempalace_diary_write`, `mempalace_diary_read`

## When to Write (Aggressively)

Save to the palace whenever any of the following is true — err on the side of *too much*, not too little:

- A non-obvious decision, trade-off, or rationale surfaced.
- A surprising bug, incident, or root cause was diagnosed.
- An architectural sketch or boundary was drawn.
- A reference URL, runbook, or CLI invocation was verified useful.
- A conversation hit a milestone (plan approved, feature shipped, investigation completed).
- You're about to lose context (PreCompact hook will force a save anyway — beat it).

**Prefer `mempalace_add_drawer` (MCP)** or **`mempalace mine <dir>`** over one-off files. A drawer is cheap; missing memory is expensive.

## When to Read (Reflexively)

Before assuming something is novel or re-deriving knowledge, **search first**:

```bash
mempalace search "caching decorator pattern"
mempalace search "ista-express task api auth" --wing appointment-projection-service
mempalace wake-up --wing <current-project>   # At session start
```

If the user references prior work ("we decided…", "last time…", "that bug from…"), search the palace before asking them to repeat.

## Auto-Save Hooks (already wired)

- **Stop hook** — Every ~15 human messages, blocks with a save instruction. Skips command-messages. Tracks per-session state in `~/.mempalace/hook_state/`. Respects `stop_hook_active` to avoid loops.
- **PreCompact hook** — Always blocks before compaction with a comprehensive save instruction. Compaction means detail is about to vanish — save first.

When a hook fires, **do the save**, don't argue with it.

## Palace Location

Default: `~/.mempalace/palace` (overridable via `~/.mempalace/config.json` or `--palace`).

Do **not** commit the palace to a project repo — it's personal, cross-project memory.

## Integration Patterns

**Session start:** `mempalace wake-up --wing <project>` → prime yourself with L0+L1 context.

**Mid-session lookup:** `mempalace search "<phrase>"` → cheap, do it before asking the user.

**Post-task:** write a drawer summarizing what changed, why, and how to reproduce.

**Before compaction:** dump non-obvious state, open questions, current hypotheses.

## Boundaries

Use `mempalace` for **lossy, narrative, cross-session memory**. Do **not** use it for:

- Strict structured data (schemas, configs) → those belong in code or project memory files.
- Secrets / credentials → never write secrets to the palace.
- Ephemeral in-conversation state → use Tasks or the Plan, not the palace.

For everything else that's worth remembering later — **save it to the palace, always**.
