---
name: omf-reference
description: In-session reference card for the oh-my-forge pack. Covers resource layout (~/forge vs ./.forge), how skills, commands, and agents are invoked, keyword routing, the Lore commit protocol, and how to list current inventories via commands rather than static tables. Load when you need to look up how oh-my-forge works, find what agents or skills are available, understand the resource precedence rules, or explain the pack to a new user.
---

# oh-my-forge Reference

A compact reference card for the oh-my-forge configuration pack.

## Resource layout

Two root locations, merged at runtime:

| Location | Purpose |
|---|---|
| `~/forge/` | Global — applies to every forge session |
| `./.forge/` | Project-local — applies to the current CWD only |

Project-local takes precedence over global. Global takes precedence over forge built-ins.

### Paths

| Resource | Global | Project-local |
|---|---|---|
| AGENTS.md | `~/forge/AGENTS.md` | `./AGENTS.md` (CWD root) |
| Agents | `~/forge/agents/*.md` | `./.forge/agents/*.md` |
| Skills | `~/forge/skills/<name>/SKILL.md` | `./.forge/skills/<name>/SKILL.md` |
| Commands | `~/forge/commands/*.md` | `./.forge/commands/*.md` |
| Config | `~/forge/.forge.toml` | — (no project-local config) |
| MCP | `~/forge/.mcp.json` | `./.mcp.json` |

Agents and commands are **flat only** — subdirectories are not walked.

Skills use one subdirectory per skill: `skills/<name>/SKILL.md`.

## Listing current inventories

Never rely on static tables here — they go stale. Run commands instead:

```bash
# List all available agents
forge list agent

# List all skills (global)
ls ~/forge/skills/

# List all commands (global)
ls ~/forge/commands/

# Full catalog with metadata (jq for readable output)
jq '.agents[].id' ~/forge/catalog-manifest.json
jq '.skills[].id' ~/forge/catalog-manifest.json
```

The authoritative single source of truth is `~/forge/catalog-manifest.json`.

## Built-in agents

| Agent | Role |
|---|---|
| `forge` | Implementer — full write/patch/shell tool set, default agent |
| `muse` | Planner — has the `plan` tool, delegates to sage |
| `sage` | Researcher — read-only, no write/patch/shell |

The pack adds many custom agents. List them with `forge list agent` or inspect `catalog-manifest.json`.

## Invoking skills

Skills are invoked via the `skill` tool — there is no prefix routing. The model reads the skill's `description` field and decides when to invoke.

```text
skill(name: "verify")
skill(name: "plan")
skill(name: "ralph")
```

The keyword routing table in `AGENTS.md` maps user phrases to skill names. It is prose read by the model each turn — not code-enforced.

## Invoking agents

Agents are invoked via the `task` tool:

```text
task(sage): "Find all files related to authentication."
task(architect): "Review this design for correctness."
task(executor): "Implement the plan at plans/2026-06-12-auth-v1.md."
```

Listing `sage`, `executor`, etc. in an agent's `tools:` frontmatter is what enables delegation to that agent.

## Commands

Commands are slash-invokable: `/verify`, `/deepinit`, etc. They live as flat `.md` files in `commands/`. Each command body uses `{{parameters}}` for user-supplied arguments and loads the corresponding skill.

## Execution modes are skills

oh-my-forge has no prefix router and no hooks. Every mode (`ralph`, `autopilot`, `ultrawork`, etc.) is a skill. The model invokes the skill based on description matching and the keyword routing table.

## Persistence

Forge has no hook API. Durable state lives in files the model reads and writes:

- `plans/YYYY-MM-DD-<slug>-v<N>.md` — plan files (see `plans/README.md` for conventions)
- `notes/` — free-form session notes

Plan file task markers (`[ ]`, `[~]`, `[x]`, `[!]`) are the execution state. The built-in `execute-plan` skill consumes them.

## Lore Commit Protocol

Every commit message follows the Lore protocol. Intent line first (why, not what), then optional body, then structured trailers.

Key trailers: `Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, `Scope-risk:`, `Not-tested:`, `Co-Authored-By: ForgeCode <noreply@forgecode.dev>`.

Full protocol in `AGENTS.md` section 4.

## Tool catalog (quick reference)

```text
task            — delegate to another agent
sem_search      — semantic search over the codebase
fs_search       — file system search by pattern
read            — read a file
write           — write a file
patch           — apply a diff
multi_patch     — apply multiple diffs
shell           — run a shell command
fetch           — HTTP fetch
skill           — load and invoke a skill
todo_write      — write a todo list
todo_read       — read a todo list
plan            — create a plan (muse agent)
followup        — structured follow-up question
```

## Configuration

- `~/forge/.forge.toml` — provider, model, retry, reasoning. See `docs/CONFIGURATION.md`.
- `~/forge/.mcp.json` + `./.mcp.json` — MCP servers, merged. See `docs/MCP.md`.
- Per-agent model/tools: edit the agent's frontmatter directly.

## Troubleshooting

Run `scripts/doctor.sh` or invoke the `doctor` skill for a full health check.

| Symptom | Fix |
|---|---|
| Custom agent missing from `forge list agent` | Must be flat in `~/forge/agents/` — subdirectories not walked |
| Skill not loading | Check `~/forge/skills/<name>/SKILL.md` has `name` + `description` frontmatter |
| Command missing from `/` menu | Must be flat in `~/forge/commands/<name>.md`, body must use `{{parameters}}` |
