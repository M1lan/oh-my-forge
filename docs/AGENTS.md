# Agents (Contributor Documentation)

> This is the **internal** documentation for contributors. For the user-facing project rules that forge auto-loads, see [`AGENTS.md`](../AGENTS.md) at the repo root.

This file documents oh-my-forge's agent model, how it maps to forgecode's actual agent loading, and how to add or modify agents.

---

## How forge loads agents

Forge loads agents from:

1. `~/forge/agents/*.md` (user-global)
2. `<project>/.forge/agents/*.md` (project-local)

Both locations are scanned **non-recursively**. Subdirectories are ignored. This is why oh-my-forge keeps all agents in a **flat layout** under `agents/*.md` -- the previous nested layout (`agents/core/`, `agents/backend/`, ...) did not work and was silently broken.

Categorization lives in `catalog-manifest.json`, not in directory names.

---

## Frontmatter schema

Required fields:

| Field | Type | Description |
|---|---|---|
| `id` | string | Kebab-case unique id. Must match the filename: `architect.md` -> `id: architect`. |
| `title` | string | Human-readable name. |
| `description` | string | Triggering mechanism. Include both capability and use-case. |
| `tools` | string[] | Non-empty list of tool names from the canonical tool catalog. |

Optional fields:

| Field | Type | Description |
|---|---|---|
| `model` | string | Override the session model for this agent. oh-my-forge typically sets `claude-opus-4-6`. |
| `reasoning` | object | `{enabled: bool, effort: "low"|"medium"|"high", summary: "auto"|"detailed"|"none"}`. |
| `temperature` | float | Model temperature override. |
| `user_prompt` | string | Pre-prompt injected on user turn. |
| `system_prompt` | string | Overrides the body. Rarely used -- prefer body. |
| `max_steps` | int | Max reasoning steps. |
| `max_turns` | int | Max turns in the sub-agent session. |

**Do NOT use** these fields -- they do not exist in the forge 2.8.0 schema and will cause agents to fail to load or be silently ignored:

- `tier` (not a thing)
- `level` (not a thing)
- `category` (use `catalog-manifest.json` instead)
- `max_walker_depth` (used to be a thing, now removed)
- `disallowedTools` (not a thing)

### Why no `tier` field

Earlier drafts of this content pack used a `tier: fast|standard|complex` field to indicate agent complexity. **This field does not exist in forge**. Forge agents are loaded uniformly and the "tier" concept is expressed through the `reasoning.effort` setting, the choice of model, and the max_steps/max_turns limits.

If an agent should be "heavier", give it `reasoning.enabled = true` and `reasoning.effort = "high"`. If it should be "lighter", leave reasoning disabled.

---

## Tool catalog

See [`REFERENCE.md#tools`](./REFERENCE.md#tools) for the authoritative list. Summary:

- **Read-only set**: `read`, `fs_search`, `sem_search`, `fetch`, `skill`, `todo_write`, `todo_read`, `task`, `"mcp_*"`
- **Write set**: add `write`, `patch`, `multi_patch`, `undo`, `remove`
- **Shell**: add `shell`
- **Planner**: add `plan`

The `"mcp_*"` wildcard matches all MCP tools dynamically. It MUST be quoted in YAML because of the `*` character.

---

## Body convention

oh-my-forge agents use XML-tagged sections in the body:

```markdown
---
id: architect
title: Architect
description: ...
tools: [...]
---

<Purpose>
One paragraph: what this agent does and why it exists.
</Purpose>

<When_To_Use>
- Trigger condition 1
- Trigger condition 2
</When_To_Use>

<Method>
Numbered or bulleted workflow.
</Method>

<Rules>
Hard constraints.
</Rules>

<Output_Format>
What the agent produces.
</Output_Format>
```

Forge does not require this structure -- it's a convention for consistency across the pack. The XML tags are plain markdown text; forge does not parse them specially.

---

## Agent tier by role

| Agent type | Reasoning | Tool set |
|---|---|---|
| Planner (`planner`, `muse`) | enabled + high effort | read-only + `plan` |
| Research / review (`architect`, `critic`, `analyst`, `verifier`, `explorer`, `tracer`) | enabled + high effort | read-only (+ `shell` for tracer/verifier) |
| Implementation heavy (`executor-high`, `refactorer`) | enabled + high effort | full write set |
| Implementation balanced (`executor`) | enabled + medium effort | full write set |
| Implementation light (`executor-low`) | disabled | full write set |
| Specialist writer (`ui-engineer`, `api-designer`, etc.) | disabled | full write set |
| Specialist read-only (`dep-auditor`, `data-modeler`, `ux-analyst`) | disabled | read-only |
| Debugger (`debugger`, `tracer`) | enabled | read-only + `shell` |
| Git (`git-master`, `git-strategist`) | disabled | read-only + `shell` |

---

## Adding a new agent

1. Create `agents/<name>.md` with the required frontmatter.
2. Write the body using the XML-tagged convention.
3. Add an entry to `catalog-manifest.json` under `agents`:
   ```json
   {
     "id": "my-agent",
     "path": "agents/my-agent.md",
     "category": "specialist",
     "status": "active",
     "core": false,
     "reasoning": false
   }
   ```
4. Run `scripts/doctor.sh --repo` to validate.
5. Update `docs/FORGE_KEYWORDS.md` if the new agent has natural-language triggers.

---

## Delegation via the `task` tool

Agents can spawn sub-agents using the `task` tool. The sub-agent gets a fresh context with its own tool set and body. Use this when:

- A large read-only investigation can run in parallel and return a summary (`sage`, `explorer`, `analyst`).
- A focused specialist can do one piece of work better than the generalist (`security-reviewer` for an auth change, `perf-optimizer` for a benchmark).
- The main agent is running low on context and needs to offload a subtask.

The task tool takes an `agent_id` and a task description. It does NOT share memory -- the sub-agent must be told everything it needs in its task prompt.

---

## Agent ID uniqueness

Every agent id must be unique. The filename must match the id (`architect.md` -> `id: architect`). The doctor script cross-checks this.

If two agents try to claim the same id, forge's loader behavior is "last one wins" but the order is not specified -- do not rely on it.

---

## Model selection

Every agent in oh-my-forge specifies `model: claude-opus-4-6` to pin behavior. Users can override this by editing the agent file in `~/forge/agents/` (the install script respects existing files unless `--overwrite` is passed).

Agents that need different models (e.g. a vision task) should specify the model explicitly in the frontmatter rather than relying on session defaults.

---

## Reasoning configuration

Only enable reasoning on agents that genuinely benefit from it:

- **Good candidates**: planning, architecture, complex review, root-cause analysis, security review, performance analysis.
- **Bad candidates**: simple edits, scaffolding, formatting, running tests, mechanical refactors.

Reasoning costs tokens and latency. The `executor-low` agent exists specifically to be fast -- do NOT add reasoning to it.

---

## See also

- [`REFERENCE.md`](./REFERENCE.md) -- skills, commands, templates, tools.
- [`../AGENTS.md`](../AGENTS.md) -- user-facing project rules (auto-loaded by forge).
- [`CONTRIBUTING.md`](./CONTRIBUTING.md) -- how to contribute.
- [`../catalog-manifest.json`](../catalog-manifest.json) -- full inventory.
