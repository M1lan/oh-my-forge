---
name: use-cortex
description: "GLOBAL mandatory preference: Use `cortex` (cortex-engine via the `fozikio serve` MCP server) for **structured cognition** — beliefs that update with evidence, threads of ongoing work, goals, journals, and identity. This is the *complement* to `mempalace`, not a replacement. Default to `mempalace_search` for verbatim recall; reach for cortex tools (`cortex/believe`, `cortex/thread_create`, `cortex/goal_set`, `cortex/journal_write`, etc.) only when you need a position, a tracked thread, or directed reasoning. NEVER write the same content to both. This is a strict, non-negotiable user preference."
---

# Use `cortex` for Structured Cognition — and only that

This is a **non-negotiable, universal preference** that applies to every scenario:

- For "did we discuss / write / decide X?" → search `mempalace` (verbatim drawer recall — exact chunks of user/assistant text). Do NOT use cortex for this.
- For "what do I currently believe about X, and what evidence updates that?" → use `cortex/believe`.
- For "this is an ongoing line of work that will span sessions" → `cortex/thread_create` + `cortex/thread_update` + `cortex/thread_resolve`.
- For "what am I trying to achieve and how should it bias my next moves?" → `cortex/goal_set`.
- For "end-of-day reflection / identity-shaping note" → `cortex/journal_write` (read with `cortex/journal_read`).
- For "I made a confirmed observation" → `cortex/observe` (then optionally `cortex/reflect` later).

There are **zero exceptions**. cortex is for cognition that has *structure and evolution*. mempalace is for content that just needs to be findable later. **Never double-write the same fact to both** — it doubles storage and embedding cost on both sides for zero gain (see `~/forge/AGENTS.md` § 6.5).

### Storage fidelity (accurate as of 2026-05)

Verified in `~/mysrc/mempalace/`:

- **Drawers are lossless.** `miner.py:766-787` upserts raw chunks (`documents=[content]`) into Chroma with no transformation. Source files are read in full and sliced via `content[start:end]` with 800-char chunks + 100-char overlap, so every byte ends up in at least one drawer.
- **Two paths are lossy by design** — don't assume "verbatim everything":
  - **AAAK diary** (`dialect.py:12`) — `mempalace_diary_write` stores a lossy summary, NOT the original prose. The code says so explicitly: "original text cannot be reconstructed." Treat diary as cortex-journal-adjacent, not as recall material.
  - **Large tool-result normalization** (`normalize.py:566-628`) — unknown tool outputs are byte-capped at 2048 with `[truncated, N chars]` before drawering during convo mining.

So the cortex/mempalace boundary is **content store vs. cognition store**, not lossy vs. lossless. Reach for mempalace when you want exact text back; reach for cortex when you want a position, thread, or goal that evolves.

## Mental Model

cortex-engine (CLI: `fozikio`) is a persistent semantic-memory + cognition layer:

- **Observations** → discrete confirmed facts (`observe`).
- **Beliefs** → positions that can be updated, contradicted, or strengthened (`believe`, `contradict`, `validate`).
- **Threads** → long-running questions or projects with status (`thread_create`/`update`/`resolve`).
- **Goals** → desired future states that bias retrieval and consolidation (`goal_set`).
- **Journal** → daily reflective entries, identity over time (`journal_write`/`read`).
- **Dream consolidation** → periodic background process that clusters, abstracts, and links observations (`dream`).

State lives in `~/cortex-workspace/cortex.db` (SQLite). The Forge and Claude Code MCP clients share this single workspace; **Codex and Gemini deliberately do NOT have cortex wired** to keep their tool-list small (mempalace alone covers ~80% of needs there).

## Curated Tool Subset (what you should reach for)

cortex-engine exposes ~57 tools. To respect the user's "no token bloat" rule, treat these as the working set; ignore the rest unless explicitly needed:

**Read first (always cheap):**
- `cortex/query` — semantic search over observations + beliefs.
- `cortex/recall` — chronological list of recent observations.
- `cortex/threads_list` — open threads (call this at session start for ongoing work).

**Write (use the right verb):**
- `cortex/observe` — a confirmed fact you learned this session.
- `cortex/believe` — a position you hold; will update on contradiction.
- `cortex/thread_create` / `cortex/thread_update` / `cortex/thread_resolve` — durable ongoing work.
- `cortex/goal_set` — what you're optimizing for; biases consolidation.
- `cortex/journal_write` — end-of-session or end-of-day reflection.

**Maintenance (occasional):**
- `cortex/dream` — consolidate (run periodically, not per session).
- `cortex/stats` — health check.

If a tool isn't in the list above, you almost certainly don't need it for routine work. Full reference: `~/cortex-workspace/.fozikio/TOOLS.md`.

## Hard Rules (do not violate)

1. **Read before you write.** Call `cortex/query` (or `mempalace_search`) before recording anything. Don't restate what's already there.
2. **Don't double-write.** A conversation note → mempalace only. A belief or thread → cortex only. Use one tool per fact.
3. **Don't use cortex for verbatim recall.** That's mempalace's job. Cortex isn't optimized for "find that exact sentence I wrote".
4. **Don't expose cortex tools in Codex/Gemini.** This is intentional in the harness configs. If you find yourself wishing for cortex there, the answer is "use mempalace, or switch to Forge/Claude Code".

## CLI Commands (when you need to shell out)

```
cd ~/cortex-workspace && fozikio health         # quick health report
cd ~/cortex-workspace && fozikio vitals         # behavioral vitals + prediction error
cd ~/cortex-workspace && fozikio wander         # serendipitous walk through the graph
cd ~/cortex-workspace && fozikio wander --from "topic"
cd ~/cortex-workspace && fozikio maintain fix   # repair data issues
cd ~/cortex-workspace && fozikio report         # weekly quality report
```

Prefer the MCP tools over shelling out — they're cheaper per call and work the same against the shared workspace.

## Boundaries

Use `cortex` for **structured, evolving cognition**. Do **not** use it for:

- Verbatim conversation recall → `mempalace_search`.
- Ephemeral in-conversation state → use the Plan or todos.
- Strict structured data (schemas, configs, secrets) → those belong in code or project memory files. **Never write secrets to cortex.**
- Quick "remember this" → that's mempalace.

For everything else that's a position, a thread, a goal, a reflection, or an identity-shaping fact — **cortex, exactly once, with the right verb**.
