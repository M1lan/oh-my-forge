# oh-my-forge Reference

Consolidated reference for skills, commands, templates, and tools shipped by oh-my-forge. Authoritative spec for contributors and for anyone extending this repo.

---

## Skills

Skills live under `skills/<name>/SKILL.md`. Forge discovers them automatically at each session start.

### Frontmatter

Skills use **exactly two** frontmatter fields:

```markdown
---
name: <kebab-case-name>
description: <one-to-three sentences describing WHAT it does and WHEN to invoke it. <=500 chars.>
---
```

Any additional fields (`argument-hint`, `level`, `tier`, `category`, etc.) will be **rejected** by the forge loader. The `description` field is the primary triggering mechanism -- forge uses it to decide whether to load the skill when the user makes a request. Write descriptions that include both the capability and clear trigger phrases.

### Invocation

Skills are invoked via the `skill` tool with just the name:

```json
{"name": "tracer"}
```

No arguments. The skill content is injected into the conversation and the model follows its instructions.

### Body convention

oh-my-forge skills use this body structure (not required by forge, but recommended for consistency):

```markdown
# <Skill Title>

## When to invoke

- User says "X" / "Y"
- Condition Z applies
- Pre-step before skill W

## Workflow

1. Step one
2. Step two
3. ...

## Rules

- Hard constraints
- Things to never do

## Output

Expected format the skill should hand back.
```

### Bundled resources

Skills may include supporting files in the same directory:

- `SKILL.md` -- the entry point (required)
- `REFERENCE.md`, `PHILOSOPHY.md`, `UTILITIES.md`, etc. -- supporting docs
- `scripts/` -- helper scripts if the skill shells out
- `assets/` -- templates, snippets, reference material

Only `SKILL.md` is auto-loaded. Supporting files should be referenced from the `SKILL.md` body so the invoker knows to read them.

### Authoring a new skill

Use the `skillify` skill -- it guides you through the process. Or manually:

1. Create `skills/<name>/SKILL.md` with the two-field frontmatter.
2. Write the description FIRST -- this determines whether future sessions find your skill. Include both capability and trigger phrases.
3. Draft the body (When to invoke / Workflow / Rules / Output).
4. Add an entry to `catalog-manifest.json` under `skills`.
5. Run `scripts/doctor.sh --repo` to validate.

---

## Commands

Commands live under `commands/<name>.md`. They are file-based slash commands invoked from the forge REPL as `/name <args>`.

### Frontmatter

```markdown
---
name: <slash-command-name>
description: <what this command does, surfaced in `/help`>
---
```

Both fields are supported. `name` is optional but recommended. There is **no** `value` field -- that was a common v1 mistake and will be silently ignored.

### Body

The body is a Handlebars template. User-supplied arguments are available as `{{parameters}}`:

```markdown
---
name: feature
description: Implement a new feature from a short description
---

Plan and implement a new feature in this codebase.

Feature description:
{{parameters}}

Follow these steps:

1. Read AGENTS.md for project conventions
2. Propose an implementation plan (files to touch, tests to add)
3. Wait for user approval before writing code
```

### Invocation

From the REPL:

```text
> /feature add user profile picture upload
```

### Authoring a new command

1. Create `commands/<name>.md` with frontmatter + body.
2. Use `{{parameters}}` (not `{{args}}`) for the argument placeholder.
3. Keep commands short -- they are prompt templates, not essays.
4. Add an entry to `catalog-manifest.json` under `commands`.
5. Run `scripts/doctor.sh --repo` to validate.

---

## Templates

Forge ships a set of built-in Handlebars prompt templates that can be overridden by dropping a file with the same name into `~/forge/templates/`.

oh-my-forge ships three overrides under `templates/` (installed with `scripts/install.sh --with-templates`):

| File | Purpose |
|---|---|
| `forge-doom-loop-reminder.md` | Stronger doom-loop breaker -- suggests switching to the `sage` agent for re-investigation or re-decomposing the task. |
| `forge-pending-todos-reminder.md` | Smarter todo reminder that references the active plan file when one exists in `plans/`. |
| `forge-partial-skill-instructions.md` | Enhanced skill catalog injection with clearer triggering guidance and keyword routing hints. |

### Handlebars context

Forge exposes these context variables to templates (partial list -- see forgecode source for authoritative details):

- `{{agent_id}}` -- the current agent
- `{{session_id}}` -- the forge session id
- `{{cwd}}` -- current working directory
- `{{user_name}}` -- local user
- `{{tools}}` -- list of available tools in this agent

### Override pattern

To customize a template without losing your edits on update, use marker-bounded sections:

```markdown
<!-- OMF:TEMPLATE:DOOM_LOOP:START -->
Your custom content here.
<!-- OMF:TEMPLATE:DOOM_LOOP:END -->
```

`scripts/omf-update.sh` preserves content between `START`/`END` markers during updates.

---

## Tools

The canonical set of tool names in forge 2.8.0. Agents declare a subset of these in their `tools:` frontmatter. Using a tool name not on this list will cause the agent to fail to load.

| Tool | Purpose |
|---|---|
| `task` | Spawn a sub-agent (the "task" tool delegates to another agent by id) |
| `sem_search` | Semantic search across the codebase |
| `fs_search` | Ripgrep-style text and glob search |
| `read` | Read a file |
| `write` | Write a new file or overwrite an existing one |
| `undo` | Revert the most recent file operation |
| `remove` | Delete a file |
| `patch` | Exact string replacement in a file |
| `multi_patch` | Multiple patches in one atomic operation |
| `shell` | Execute a shell command |
| `fetch` | HTTP fetch a URL |
| `skill` | Load a skill by name |
| `todo_write` | Write or update the todo list |
| `todo_read` | Read the current todo list |
| `plan` | Plan tool (for the muse/planner agents) |
| `followup` | Ask the user a follow-up question |
| `mcp_*` | All MCP tools (glob-wildcarded) |

### Tool selection by agent role

| Role | Typical tool set |
|---|---|
| Read-only research (architect, critic, explorer, analyst, verifier) | `read`, `fs_search`, `sem_search`, `fetch`, `skill`, `todo_*`, `task`, `mcp_*` |
| Read + shell (tracer, debugger, verifier) | Add `shell` |
| Full implementation (executor, refactorer, ui-engineer, etc.) | Add `write`, `patch`, `multi_patch`, `undo`, `remove`, `shell` |
| Planner (planner, muse) | Read-only set + `plan` |

### Do not use

These tool names are **invalid** in forge 2.8.0 and will cause agents to fail to load:

- `edit` (use `patch` or `multi_patch`)
- `bash` (use `shell`)
- `glob` (use `fs_search`)
- `grep` (use `fs_search`)
- `net_fetch` (use `fetch`)
- `skill_fetch` (use `skill`)

If you see these in an agent file, it was written for a different tool's schema and needs to be fixed.

---

## New skills in v2.1 (2026-06-12)

The following skills were added in the OMC parity wave. They follow the same frontmatter conventions as above.

### Ported workflows

| Skill | Category | Description |
|---|---|---|
| `ask` | meta | Consult a second AI CLI (codex, claude, or gemini) for adversarial review or tie-breaking. |
| `code-review` | quality | Structured diff review with severity ratings (Critical/Major/Minor/Nit) and a merge verdict. |
| `security-review` | quality | OWASP Top 10 + secrets + trust-boundary audit; zero-noise bias, BLOCK/WATCH/CLEAR verdict. |
| `tdd` | quality | Red-green-refactor discipline. Iron Law: no production code without a failing test first. |
| `ultragoal` | execution | Durable multi-goal initiative tracked across sessions via a plan file ledger. |
| `deepinit` | meta | Generate or regenerate hierarchical AGENTS.md documentation across the codebase. |
| `mcp-setup` | meta | Guided wiring of MCP servers into `~/forge/.mcp.json` or `./.mcp.json`. |
| `omf-reference` | meta | In-session reference card for oh-my-forge resource layout, routing, and conventions. |

### House preference skills (always-active tooling)

These skills encode standing preferences. Forge loads them for all relevant work without explicit invocation.

| Skill | Description |
|---|---|
| `write-bash` | GNU Bash 5.3+ house style -- all shell and Bash work follows these rules. |
| `use-rg` | Always use `rg` (ripgrep) instead of `grep` for all text search. |
| `use-fd` | Always use `fd` instead of `find` for all file discovery. |
| `use-gnu-tools` | Always use Homebrew-installed GNU tools over macOS/BSD built-ins. |
| `karpathy-guidelines` | Anti-overengineering behavioral guidelines -- surgical changes, simplicity first. |
| `typescript-pro` | Advanced TypeScript: generics, branded types, discriminated unions, tRPC. |
| `emacs-integration` | Bidirectional Emacs editor integration via MCP tools on `~/.local/state/emacs/mcp.sock`. |
| `use-grepai` | Semantic code search via the `grepai` CLI (call graphs, intent search, property graphs). |

---

## Catalog manifest

Every agent, skill, command, and template shipped by oh-my-forge is listed in `catalog-manifest.json` at the repo root. This file is the single source of truth for `scripts/install.sh`, `scripts/doctor.sh`, and `scripts/uninstall.sh`.

See `catalog-manifest.schema.json` for the JSON Schema.

When adding a new agent/skill/command, update the manifest. The doctor script cross-checks that every manifest entry has a corresponding file and vice versa.
