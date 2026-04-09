# oh-my-forge Aggressive Rewrite — v1

## Objective

Transform `oh-my-forge` from a non-functional, miscopied port of `oh-my-claudecode` into a **first-class, actually-working** configuration pack for ForgeCode. The current pack ships a dead `forge.yaml` file that ForgeCode cannot load, agent files with wrong tool names, and skill files with wrong frontmatter. This rewrite fixes all of that and ports the highest-value patterns from the three reference configs (`oh-my-claudecode`, `oh-my-codex`, `oh-my-gemini-cli`) into a shape that ForgeCode natively understands.

No npm, no Node.js, no TypeScript, no wrapper CLI. Pure configuration files and bash scripts that drop into `~/forge/` (or `./.forge/`) and work.

## Revision history

- **v1 (2026-04-09)**: Initial plan.
- **v1-reviewed (2026-04-09)**: Updated after independent critical review. Fixes 8 factual errors in Ground Truth that would have propagated into every generated file (command frontmatter, `updates.frequency` enum, project-local path asymmetry, missing third skill path `~/.agents/skills/`, wrong body variable `{{args}}` vs `{{parameters}}`, invalid field `max_walker_depth`, under-specified agent frontmatter fields, mis-framed skill frontmatter stripping). Cuts 4 low-value tasks (omf-setup skill, multiple example starters, .github workflows, `debug` skill that duplicates `tracer`). Consolidates some doc files. Clarifies which B/C tasks are PORT vs SYNTHESIZE.

## Scope

**In scope (Aggressive — all phases):**
- Phase A — Foundation fixes (delete `forge.yaml`, ship `.forge.toml`, fix tool names, mcp, templates, install script, AGENTS.md)
- Phase B — Port high-value skills (rewritten for forge's `skill` tool invocation model)
- Phase C — Rewrite / add agents with correct frontmatter and XML-tagged prompt bodies
- Phase D — Catalog manifest, doctor script, README + docs rewrite
- Phase E — Injection seams, keyword routing table, stage-gated team pipeline, commit trailers, custom commands

**Out of scope (explicit non-goals):**
- No Rust crates, no Cargo workspace
- No Node.js / npm / TypeScript / JavaScript hook scripts
- No wrapper CLI (no `omf` binary — forgecode IS the CLI)
- No multilingual READMEs
- No `benchmarks/`, `playground/`, `self-improve/autoresearch` subsystems
- No `.claude-plugin/`, `gemini-extension.json`, or any other foreign plugin manifest
- No hooks (forgecode has no hook API — templates are the closest thing)

## Ground Truth (verified against forgecode source)

This section captures the facts the plan depends on. The executing sub-agent MUST treat these as authoritative. These claims have been cross-checked against a local clone of the forgecode source — see inline source citations. If any claim in this section appears to be contradicted by forgecode source during execution, STOP and ask the user; do not silently adapt.

### ForgeCode layout — COMPLETE PATH TABLE

Verified against `crates/forge_domain/src/env.rs:73-151` and `crates/forge_repo/src/skill.rs:14-32`. **The project-local paths are NOT uniform** — some resources live at the CWD root, others under `./.forge/`.

| Resource | Global path | Project-local path | Notes |
|---|---|---|---|
| TOML config | `~/forge/.forge.toml` | (no project-local) | Only global — per `crates/forge_config/src/reader.rs:48-61` |
| MCP config | `~/forge/.mcp.json` | `./.mcp.json` (CWD root, **not** `./.forge/.mcp.json`) | `env.rs:82,97` |
| Project rules | `~/forge/AGENTS.md` | `./AGENTS.md` (CWD root) | `env.rs:146,151` — auto-loaded by forgecode |
| Agents | `~/forge/agents/*.md` | `./.forge/agents/*.md` | Project overrides global overrides built-in |
| Skills | `~/forge/skills/<name>/SKILL.md` | `./.forge/skills/<name>/SKILL.md` | See THREE-path note below |
| Commands | `~/forge/commands/*.md` | `./.forge/commands/*.md` | |
| Templates | `~/forge/templates/*.md` | (no project-local) | Override built-in Handlebars partials |
| Conversations DB | `~/forge/.forge.db` | n/a | SQLite |
| Snapshots | `~/forge/snapshots/` | n/a | Per-file backups on every write |
| History | `~/forge/.forge_history` | n/a | REPL history |
| Permissions | `~/forge/permissions.yaml` | n/a | Tool allow/deny lists |

**THREE skill paths** (not two) per `crates/forge_repo/src/skill.rs:14-32`:
1. Global: `~/forge/skills/<name>/SKILL.md`
2. Agents: `~/.agents/skills/<name>/SKILL.md` (NOTE: `~/.agents/`, a hidden home dir — distinct from `~/forge/`)
3. Project-local: `./.forge/skills/<name>/SKILL.md`

Precedence order (highest first): **project > agents > global > built-in**. All doctor/uninstall/cross-ref tasks MUST account for all three paths.

### Canonical tool names (from `crates/forge_domain/src/tools/catalog.rs:41-61` enum `ToolCatalog`)

Use these exact names in every agent's `tools:` frontmatter. Tool name matching is case-insensitive + whitespace-trimmed (`catalog.rs:1827-1843`) but we ship snake_case lowercase for consistency.

```
task            sem_search      fs_search       read
write           undo            remove          patch
multi_patch     shell           fetch           skill
todo_write      todo_read       plan            followup
mcp_*           <agent_id>      (e.g. sage, forge, muse as tools)
```

Notes:
- `skill` — NOT `skill_fetch`. Invokes the on-demand skill loader. `create-skill/SKILL.md` and `forge-partial-skill-instructions.md` both reference it as the `skill` tool.
- `fetch` — NOT `net_fetch`. `ToolCatalog::Fetch` at `catalog.rs:810`.
- `fs_search` — canonical name. The alias `search` IS registered in `crates/forge_app/src/tool_resolver.rs:15` as `("search", ToolName::new("fs_search"))`, so the built-in `sage.md` using `search` is NOT broken. But **we use `fs_search` everywhere in oh-my-forge for forward compatibility and clarity**.
- `plan` — planning tool, used by `muse`.
- `followup` — follow-up question tool.
- **Agents are also valid tool names.** `muse.md` lists `sage` in its tools list — this lets muse delegate to sage as if it were a tool. Agent tool names must match the `id` of a shipped agent.
- `mcp_*` glob — exposes ALL MCP tools to the agent.

### `.forge.toml` schema (actual, verified)

Top-level keys are **FLAT**, not nested under `[tools.*]`. Verified against the live `~/forge/.forge.toml` and the upstream `forge.schema.json:1-250`.

This is the baseline we ship as `oh-my-forge/.forge.toml`:

```toml
# String (JSON-schema URL for editor validation)
"$schema" = "https://forgecode.dev/schema.json"

# Top-level integer/float knobs (all optional)
max_search_lines = 1000
max_search_result_bytes = 10240
max_fetch_chars = 50000
max_stdout_prefix_lines = 100
max_stdout_suffix_lines = 100
max_stdout_line_chars = 500
max_line_chars = 2000
max_read_lines = 2000
max_file_read_batch_size = 50
max_file_size_bytes = 104857600
max_image_size_bytes = 262144
tool_timeout_secs = 300
auto_open_dump = false
max_conversations = 100
max_sem_search_results = 100
sem_search_top_k = 10
max_extensions = 15
max_parallel_file_reads = 64
model_cache_ttl_secs = 604800
top_p = 0.8
top_k = 30
max_tokens = 20480
max_tool_failure_per_turn = 3
max_requests_per_turn = 100
restricted = false
tool_supported = true

# Table sections
[retry]
initial_backoff_ms = 200
min_delay_ms = 1000
backoff_factor = 2
max_attempts = 8
status_codes = [429, 500, 502, 503, 504, 408, 522, 520, 529]
suppress_errors = false

[http]
connect_timeout_secs = 30
read_timeout_secs = 900
pool_idle_timeout_secs = 90
pool_max_idle_per_host = 5
max_redirects = 10
hickory = false
tls_backend = "default"
adaptive_window = true
keep_alive_interval_secs = 60
keep_alive_timeout_secs = 10
keep_alive_while_idle = true
accept_invalid_certs = false

[session]
provider_id = "claude_code"          # or anthropic, openai, google_ai_studio, bedrock, ollama, lm_studio, ...
model_id = "claude-opus-4-6"

[updates]
frequency = "daily"                   # Valid values: daily | weekly | always (verified at forge.schema.json:881-889)
auto_update = false                   # oh-my-forge ships auto_update=false as a safer default than the live install

[compact]
retention_window = 6
eviction_window = 0.2
max_tokens = 2000
token_threshold = 100000
message_threshold = 200
on_turn_end = false
# Optional: turn_threshold = N, model = { provider_id = "...", model_id = "..." }

[reasoning]
effort = "high"                       # none | minimal | low | medium | high | xhigh | max
enabled = true
```

**`updates.frequency` enum correction**: The valid values are **`daily`, `weekly`, `always`** ONLY (verified at `forge.schema.json:881-889`, `$defs/UpdateFrequency`). The earlier draft of this plan incorrectly listed `never` and `monthly`; those will cause a deserialization error.

**There is NO `[agent.<id>]` section in real-world use.** Per-agent overrides go in each agent's .md frontmatter. There's NO top-level `rules` string and NO `custom_rules` top-level key either. Project rules go in `AGENTS.md` (auto-loaded) and per-agent `custom_rules` lives in agent frontmatter.

**There is NO `[[commands]]` inline command definition in real-world use** — commands live as `commands/*.md` files with Handlebars + frontmatter. (The schema allows inline `[[commands]]` too, but we ship files for discoverability and consistency with forge's conventions.)

### Agent file format (verified against built-in `forge.md`, `sage.md`, `muse.md` and the `AgentDefinition` struct at `crates/forge_repo/src/agent_definition.rs:16-132`)

```markdown
---
id: "agent-id"
title: "Human-readable title"
description: "One-paragraph description. THIS is what other agents and the skill loader use to pick this agent — make it thorough."
reasoning:
  enabled: true              # Optional; turn on extended thinking
tools:
  - read
  - fs_search
  - sem_search
  - fetch
  - skill
  - todo_write
  - todo_read
  - task
  - "mcp_*"
user_prompt: |-
  <{{event.name}}>{{event.value}}</{{event.name}}>
  <system_date>{{current_date}}</system_date>
---

# Body (Handlebars-enabled Markdown)

The body becomes the agent's `system_prompt` automatically — `crates/forge_repo/src/agent.rs:151-154`
shows `parse_agent_file` auto-populating `.system_prompt(Template::new(result.content))`. The
resulting system_prompt is then wrapped by the runtime in the `forge-custom-agent-template.md`
scaffold, which adds: system_information, tool_usage_instructions, project_guidelines
(if custom_rules), and non_negotiable_rules. You don't have to add those sections yourself.

Available Handlebars context in the body:
- {{agent.title}}, {{agent.description}}
- {{tool_names.task}}, {{tool_names.fs_search}}, etc. (the actual exposed tool names)
- {{#if tool_supported}} ... {{else}} ... {{/if}} (whether the model supports structured tool calls)
- {{#if skills}} ... {{/if}} (whether any skills are available)
- {{> forge-partial-skill-instructions.md}} (partial includes)
- {{> forge-partial-system-info.md}}
- {{custom_rules}}, {{tool_information}}, {{skills}}
```

**Canonical agent frontmatter fields** (exhaustive, from `AgentDefinition` struct `crates/forge_repo/src/agent_definition.rs:16-132`):

| Field | Type | Purpose |
|---|---|---|
| `id` | string | **Required.** Unique agent id. Quote it for consistency with built-ins (e.g. `id: "architect"`). |
| `title` | string | Human-readable title. |
| `description` | string | **PRIMARY triggering mechanism** — what the task/skill loader reads to decide when to delegate here. Be thorough. |
| `tool_supported` | bool | Whether the model natively supports structured tool calls. Usually omit (defaults to true for modern models). |
| `provider` | string | Override default provider for this agent (e.g. `anthropic`). |
| `model` | string | Override default model (e.g. `claude-sonnet-4-5`). |
| `system_prompt` | template | Normally AUTO-populated from the body — don't set manually. |
| `user_prompt` | template | User-input template. All built-ins use: `<{{event.name}}>{{event.value}}</{{event.name}}>\n<system_date>{{current_date}}</system_date>`. |
| `tools` | list | Canonical snake_case tool names + optional agent IDs + optional `"mcp_*"` glob. |
| `max_turns` | int | Cap turns. |
| `compact` | table | Per-agent compact config (overrides global). |
| `custom_rules` | string | Extra rules appended to the agent's system prompt (via Handlebars `{{custom_rules}}`). |
| `temperature` | float 0.0–2.0 | Per-agent temperature. |
| `top_p` | float 0.0–1.0 | Per-agent top_p. |
| `top_k` | int 1–1000 | Per-agent top_k. |
| `max_tokens` | int 1–100_000 | Per-agent max output tokens. |
| `reasoning` | table | `{enabled, effort, max_tokens, exclude, supported}`. |
| `max_tool_failure_per_turn` | int | Tool failure cap before forcing completion. |
| `max_requests_per_turn` | int | Request cap per turn. Useful for heavy agents (ralph/autopilot). |

**Fields we will NOT use** (because they don't exist in `AgentDefinition`):
- `tier` — oh-my-claudecode convention, not in forgecode
- `max_walker_depth` — does NOT exist in the agent struct. This was an error in the research report. It exists as a top-level `.forge.toml` schema field in some schema versions but is absent from the active agent deserializer. Do not use.
- `disallowedTools` — claudecode convention, not supported
- `level` — codex convention, not supported

### Skill file format (verified against built-in `create-skill/SKILL.md` and `SkillMetadata` struct at `crates/forge_repo/src/skill.rs:250-281`)

```markdown
---
name: verb-skill-name           # verb-based naming: execute-plan, create-report
description: Primary triggering mechanism. Include BOTH what it does AND when to use it. Example: "Comprehensive PDF processing with support for rotation, text extraction, form filling. Use when you need to work with .pdf files."
---

# Skill Title

Markdown body. Under 500 lines preferred. Progressive disclosure via references/:

- scripts/         executable code (bash, python) — deterministic and token-free
- references/      docs to load when needed (e.g. references/aws.md)
- assets/          files used in output (templates, logos, boilerplate)
```

**Only `name` and `description` in frontmatter.** The built-in `create-skill/SKILL.md:370` is explicit: "Do not include any other fields in YAML frontmatter." This is an **authoring guideline**, not a parser rejection — the `SkillMetadata` struct at `crates/forge_repo/src/skill.rs:250-281` uses plain `#[derive(Deserialize)]` with `Option<String>` fields, so gray_matter silently drops unknown frontmatter keys. Existing skills with `argument-hint`, `level`, `aliases`, `triggers`, `user-invocable` load without error — the extras are ignored. We **remove them for consistency** (not because they cause failures). We keep the `<Purpose>`/`<Steps>`/etc. XML-tagged body structure because it's a prompting-style choice not a schema constraint, and it's proven in both claudecode and codex.

**Skill body token substitution** (not Handlebars, literal `.replace()` per `crates/forge_repo/src/skill.rs:239-243`):
- `{{global_skills_path}}` → absolute path to `~/forge/skills/`
- `{{agents_skills_path}}` → absolute path to `~/.agents/skills/` (or empty string if HOME unavailable)
- `{{local_skills_path}}` → absolute path to `./.forge/skills/`

Use these when a skill body needs to reference absolute filesystem paths for its scripts/references/assets in a portable way. They are NOT Handlebars — no conditionals, no helpers, pure string replacement.

### Command file format (verified against the `Command` struct at `crates/forge_domain/src/command.rs:11-21`, the built-in `commands/github-pr-description.md`, and fixtures at `crates/forge_services/src/fixtures/commands/{basic,multiline}.md`)

```markdown
---
name: command-name                              # Optional; filename is used as fallback
description: One-line shown in slash-menu autocomplete
---

# Command body (Handlebars-enabled)

User arguments are referenced as {{parameters}}
```

**Command frontmatter — CORRECTED from v1 draft**. The real `Command` struct has exactly three fields:
```rust
pub struct Command {
    pub name: String,       // filename fallback if omitted
    pub description: String,
    pub prompt: Option<String>,  // the markdown body after frontmatter
}
```

**There is NO `value: false|true` field.** The v1 draft of this plan incorrectly documented such a field. The body variable is `{{parameters}}`, NOT `{{args}}`. See `commands/github-pr-description.md:8` for the canonical example — it's literally just `{{parameters}}` on a line.

Commands are invoked with `/name` in the REPL. They live in `~/forge/commands/*.md` (global) or `./.forge/commands/*.md` (project).

### Plan file format (verified against `crates/forge_repo/src/skills/execute-plan/SKILL.md:32-39`)

- Filename: `plans/YYYY-MM-DD-<slug>-v<N>.md`
- Task status markers (on list items): `[ ]` PENDING, `[~]` IN_PROGRESS, `[x]` DONE, `[!]` FAILED
- NO `<task_status>` XML wrapper (that was a hallucination in the initial research report)
- The `execute-plan` skill commits to completing ALL tasks before moving on (`SKILL.md:10-14`). It updates markers in-place as it executes.

### Templates that can be overridden at `~/forge/templates/`

From the upstream forgecode `templates/` directory:

```
forge-custom-agent-template.md         # Main body scaffold wrapping every agent
forge-partial-system-info.md           # Injects OS/shell/cwd/git info
forge-partial-skill-instructions.md    # Teaches agents how to use `skill` tool
forge-partial-tool-use-example.md      # Tool call example
forge-partial-tool-error-reflection.md # Forces reflection after tool error
forge-partial-summary-frame.md         # Compacted conversation frame
forge-doom-loop-reminder.md            # Break out of repetitive loops
forge-pending-todos-reminder.md        # Per-turn todo reminder
forge-commit-message-prompt.md         # `forge commit` prompt
forge-command-generator-prompt.md      # `forge suggest` prompt
forge-system-prompt-title-generation.md # Title generator
forge-tool-retry-message.md            # Retry nudge
```

Any same-named file in `~/forge/templates/` overrides the built-in. This is forgecode's only native hook-like mechanism. Handlebars context is the full environment + `{{custom_rules}}`, `{{tool_information}}`, `{{skills}}`.

### Built-in agents

- `forge` — implementer (full tool set)
- `sage` — researcher (read-only)
- `muse` — planner (has `plan` tool and can call `sage` as a sub-tool)

### Built-in skills

- `create-skill` — skill authoring workflow
- `execute-plan` — reads plans/*.md, executes PENDING tasks, updates markers
- `github-pr-description` — PR description generator

### Providers (30+)

`forge`, `anthropic`, `claude_code`, `openai`, `openai_compatible`, `azure`, `google_ai_studio`, `vertex_ai`, `vertex_ai_anthropic`, `bedrock`, `deepseek`, `xai`, `github_copilot`, `open_router`, `cerebras`, `ollama`, `lm_studio`, `llama_cpp`, `vllm`, `jan_ai`, and more. Full list at `crates/forge_repo/src/provider/provider.json`. We use `claude_code` as the default in the sample config to match the `AGENTS.md` of the workbench.

---

## Implementation Plan

All tasks use the `[ ] PENDING` format. An executing agent should update markers to `[~] IN_PROGRESS` and then `[x] DONE` as it proceeds. FAILED tasks become `[!]` with a reason.

### Phase A — Foundation Fixes (CRITICAL)

The current oh-my-forge does not work at all as a forge config because of these issues. Fix them first.

- [ ] A1. **Delete `forge.yaml`**. The file is a dead YAML that forgecode cannot load. Use `remove` tool.
- [ ] A2. **Create `.forge.toml`** at oh-my-forge repo root using the verified flat schema shown in Ground Truth. Populate with sensible defaults: `[session]` using `claude_code`/`claude-opus-4-6`, `[reasoning] enabled=true effort=high`, `[updates] frequency=daily auto_update=false` (safer default than the live install), `[compact]` matching the live install, `[retry]` matching the live install. Add a commented-out `[[commands]]` section STUB ONLY (2 lines showing structure) for users who prefer inline commands — we ship file-based commands in Phase E4 as the primary surface. Add a top-of-file comment block explaining that this is the oh-my-forge baseline and users can copy to `~/forge/.forge.toml`. **Never use `frequency = "never"` or `frequency = "monthly"` — those are not in the enum.**
- [ ] A3. **Create `.mcp.json.example`** at oh-my-forge repo root with 3-4 representative MCP servers (emacs, github, filesystem, fetch). All servers commented out by default with `// TODO: uncomment and configure`. Use the live `~/forge/.mcp.json` emacs entry as the first example. Include a comment explaining this is an example and should be copied to `~/forge/.mcp.json` and customized. Also document the `forge mcp import` subcommand as an alternative ingress path.
- [ ] A4. **Create `AGENTS.md`** at oh-my-forge repo root (user-facing project rules file that forgecode auto-loads). Adapt from the existing `docs/AGENTS.md` content but:
  - Document the ACTUAL forgecode architecture (no tier system, no `max_walker_depth` field)
  - List the three built-in agents (forge/sage/muse) + any oh-my-forge custom agents
  - Explain skill invocation via the `skill` tool
  - Include a keyword-routing section (from Phase E1)
  - Include the commit trailer protocol (from Phase E3)
  - Reference the execution modes as SKILLS (not prefix-triggered modes)
- [ ] A5. **Fix every agent's `tools:` frontmatter**. For each file under `agents/**/*.md`:
  - Replace `read, write, patch, shell` boilerplate with a considered tool subset for that agent's role — this is a **deliberate expansion** of the tool surface, not a bugfix alone
  - Read-only agents (architect, code-reviewer, security-reviewer, analyst, critic, verifier, explorer, tracer, scientist, data-modeler, dep-auditor, ux-analyst, doc-writer-read): `read`, `fs_search`, `sem_search`, `fetch`, `skill`, `todo_write`, `todo_read`, `task`, `mcp_*`
  - Implementation agents (executor, executor-low, executor-high, refactorer, ui-engineer, db-engineer, migrator, test-writer): add `write`, `patch`, `multi_patch`, `undo`, `remove`, `shell` on top of the read set
  - Planner agents (planner): add `plan` to the read set
  - Remove `tier: fast|standard|complex` from all frontmatter (not a real forgecode field)
  - Remove `max_walker_depth` from all frontmatter if present (not a real forgecode field)
  - Keep `reasoning: enabled: true` only for heavyweight agents: architect, executor-high, code-reviewer, debugger, critic, verifier, analyst, tracer, security-reviewer, perf-optimizer, planner
  - Explicitly exclude `architect-low` and `executor-low` from reasoning (these are the intentionally-lightweight variants; the `-low` suffix is meaningful, not a typo for `architect`/`executor`)
  - Quote the `id` value (matches built-in style: `id: "architect"` not `id: architect`)
  - Add `user_prompt` frontmatter block matching the built-in agents' pattern (for event + date injection)
- [ ] A6. **Delete the two existing install scripts** (`scripts/install.sh` and `scripts/install-global.sh`) **and write ONE** `scripts/install.sh`:
  - Target `~/forge/` (NOT `~/.forge/`) for global installs
  - Support `--project <path>` (installs to `<path>/.forge/`) and `--global` (installs to `~/forge/`, default)
  - Uses `rsync -a` to copy: `agents/`, `skills/`, `commands/`, `templates/`
  - Uses `cp -n` (no-clobber) for `.forge.toml` so it doesn't overwrite user config; prints a diff hint if the target already exists
  - Uses `cp -n` for `.mcp.json.example` → `.mcp.json` (no-clobber)
  - **NEVER copies `AGENTS.md` to a project-local location.** `AGENTS.md` is inherently project-specific. Install copies to `~/forge/AGENTS.md` ONLY, and only with `--with-agents-md` flag (default: skip). Without the flag, print a hint telling the user how to manually merge the shipped `AGENTS.md` content into their global or project AGENTS.md.
  - Prints a warning if it detects a stray `~/forge/forge.yaml` from the old v1 install (file is ignored by forgecode, but should be deleted)
  - Bash 5.3+ style per `write-bash` skill: `set -euo pipefail`, `shopt -s failglob`, functions, `main "$@"`, log helpers
  - Ends by printing a "what was installed" summary and a "next steps" hint (`./scripts/doctor.sh`)
- [ ] A7. **Write `scripts/doctor.sh`**:
  - Checks `~/forge/` exists
  - Checks `~/forge/.forge.toml` is valid TOML. Validation order: prefer `toml-cli` (if installed), fall back to `python3 -c 'import tomllib; tomllib.load(open("PATH","rb"))'` (Python 3.11+; tomllib is in the stdlib), fall back to a basic grep-syntax check if neither is available
  - Checks `~/forge/.mcp.json` is valid JSON via `jq . < FILE >/dev/null` or `python3 -m json.tool < FILE >/dev/null`
  - Lists every agent file found in both global (`~/forge/agents/`) and project (`./.forge/agents/`) dirs
  - Lists every skill dir found in ALL THREE paths: `~/forge/skills/`, `~/.agents/skills/`, `./.forge/skills/`
  - Lists every command file found in both global and project dirs
  - Cross-references `catalog-manifest.json` (Phase D1) against actual files: flags mismatches (files in manifest but not on disk, files on disk but not in manifest)
  - Runs `forge list agent` and `forge list skill` and `forge list cmd` if `forge` binary is available (soft check — warns but doesn't fail if absent)
  - Checks every shipped agent's `tools:` list against the canonical tool name set (hardcoded fixture list from Ground Truth, plus valid agent IDs discovered from actually-shipped agent files)
  - Flags any legacy `forge.yaml` file in `~/forge/`
  - Flags `[updates] frequency` values outside `daily|weekly|always`
  - Prints a green `OK` or red `FAIL` banner with a summary
  - Bash 5.3+ style, `set -euo pipefail`, exit 0 on OK, exit 1 on any FAIL
- [ ] A8. **Write `scripts/uninstall.sh`**:
  - Removes only the oh-my-forge-provided files (never user's own files)
  - Uses catalog-manifest.json to enumerate what to remove (requires Phase D1 to be done first; A8 depends on D1)
  - Dry-run mode via `--dry-run` flag (shows what would be removed)
  - Asks confirmation unless `--yes` is passed
  - Bash 5.3+ style
- [ ] A9. **Write `scripts/migrate-from-v1.sh`** (new task, replaces the vague "install script prints a warning" from the v1 draft):
  - Detects a v1 install: looks for `~/forge/forge.yaml`, `~/forge/.forge/forge.yaml`, `./forge.yaml` in CWD
  - For each detected v1 file: backs it up to `<file>.v1-backup`, prints a diff summary against the new `.forge.toml`, and deletes the v1 file ONLY with `--yes`
  - Detects v1 agents (those with `tier:` frontmatter field) in `~/forge/agents/` and offers to migrate them to the new frontmatter format
  - Dry-run mode via `--dry-run`
  - Bash 5.3+ style

### Phase B — High-Value Skills Port

Port the top skills from the reference codebases, rewritten for forgecode's skill model (2-field frontmatter, discoverability via description, XML-tagged body). Each task creates one skill directory with a `SKILL.md` plus optional `scripts/`, `references/`, `assets/`.

- [ ] B1. **Rewrite existing skills to conform to forgecode format**. For each of the 13 existing skills in `skills/`:
  - Strip all non-standard frontmatter fields (`argument-hint`, `level`, `aliases`, `triggers`, `user-invocable`) — keep only `name` and `description`
  - Rewrite `description` to be the PRIMARY triggering mechanism: include both WHAT it does and WHEN to use it (follow the `docx` skill example from `create-skill/SKILL.md:368`)
  - Keep the `<Purpose>/<Use_When>/<Steps>` body structure — it's good prompting
  - Ensure no body text assumes a skill-prefix triggering model (e.g. remove "User says 'ralph:'..." phrasing). Instead say "When the user asks for a task that must complete without giving up, use this skill."
  - Fix any references to Claude-specific tool names (`TodoWrite` → `todo_write`, etc.)
  - Skills to update: `autopilot`, `ralph`, `ultrawork`, `turbo`, `eco`, `team`, `trace`, `deep-interview`, `learner`, `scaffold`, `ultraqa`, `tailwind-v4`, `docker`
- [ ] B2. **Port skill: `critic`**. Final-gate multi-perspective review skill. Source: `oh-my-claudecode/skills/` (implicit — implemented as an agent there) + `oh-my-codex/prompts/critic.md`. This is the heavyweight "pre-commit quality gate" skill. Includes: pre-commitment predictions, verification, multi-perspective review (security/ops/maintainer), gap analysis, self-audit, realist check, adaptive adversarial escalation, evidence requirements. Reference the `critic` agent created in Phase C.
- [ ] B3. **Port skill: `verify`**. Evidence-based completion check skill. Source: `oh-my-claudecode/skills/verify/SKILL.md` and `oh-my-codex/prompts/verifier.md`. Skill that asks "is this actually done?" with an explicit evidence checklist.
- [ ] B4. **Port skill: `plan`** (standard planning). Source: `oh-my-claudecode/skills/plan/SKILL.md`. Standard planning workflow. Writes to `plans/YYYY-MM-DD-<slug>-v<N>.md`. Uses the forgecode plan format with `[ ]/[~]/[x]/[!]` markers. Delegates to `muse` agent via the `task` tool (since muse has the `plan` tool).
- [ ] B5. **Port skill: `ralplan`** (consensus planning with deliberation). Source: `oh-my-claudecode/skills/ralplan/SKILL.md`. Planner+architect+critic iterative deliberation with optional `--deliberate` flag for high-risk work. Requires antithesis/tradeoff/synthesis sections.
- [ ] B6. **Port skill: `ai-slop-cleaner`**. Source: `oh-my-claudecode/skills/ai-slop-cleaner/SKILL.md`. Regression-safe deletion-first cleanup pass. Optional post-ralph/post-autopilot step.
- [ ] B7. **Port skill: `cancel`**. Source: `oh-my-claudecode/skills/cancel/SKILL.md`. Clean mode exit with dependency-ordered cleanup. Writes `.forge/state/cancel-signal.json`.
- [ ] B8. **Port skill: `explore`**. Source: `oh-my-claudecode/skills/` (implicit — agent-based there) + codex `explore.md`. Read-only codebase exploration skill that delegates heavy search to the `sage` agent via the `task` tool.
- [ ] B9. **Port skill: `tracer`** (evidence-driven debugging). Source: `oh-my-claudecode/skills/trace/SKILL.md`. Replace the existing `trace` skill with this richer version.
- [ ] B10. **Port skill: `note`**. Source: `oh-my-codex/skills/note/SKILL.md`. Compaction-resilient notepad at `.forge/state/notepad.md`. Three sections: Priority (500-char limit), Working (auto-prune), MANUAL (user-protected).
- [ ] B11. **Port skill: `recall`**. Source: `oh-my-gemini-cli/commands/omg/recall.toml`. State-first search before transcript fallback. Reads `.forge/state/*.json` and `.forge/state/notepad.md` first.
- [ ] B12. **Port skill: `visual-verdict`**. Source: `oh-my-claudecode/skills/visual-verdict/SKILL.md`. Structured JSON visual diff scoring with score threshold (90+). Writes `.forge/state/visual-progress.json`.
- [ ] B13. **Port skill: `deep-dive`**. Source: `oh-my-claudecode/skills/deep-dive/SKILL.md`. Two-stage pipeline: trace → deep-interview with 3-point injection.
- [ ] B14. **Port skill: `wiki`**. Source: `oh-my-claudecode/skills/wiki/SKILL.md`. Persistent markdown knowledge base at `.forge/wiki/*.md` that compounds across sessions.
- [ ] B15. **Port skill: `remember`**. Source: `oh-my-claudecode/skills/remember/SKILL.md`. Review reusable project knowledge; routes to note/wiki/docs.
- [ ] B16. **Port skill: `skillify`**. Source: `oh-my-claudecode/skills/skillify/SKILL.md`. Auto-extract a reusable skill from the current conversation. Produces a draft SKILL.md compatible with forgecode's 2-field frontmatter.
- [ ] B17. **CUT. Merged into B9 (`tracer` skill).** The v1 draft proposed a separate `debug` skill but it substantially duplicates `tracer`. Merge any unique debugging-specific content (log inspection, snapshot navigation) into the body of the `tracer` skill instead.
- [ ] B18. **Port skill: `release`** (oh-my-forge release flow). Source: `oh-my-claudecode/skills/release/SKILL.md`. Adapted for oh-my-forge's own release: bump version in catalog-manifest, update CHANGELOG, tag, push.
- [ ] B19. **New skill: `doctor`**. Thin wrapper that invokes `scripts/doctor.sh` and interprets the result with guided fixes for common failures. Kept because it's usable via the `skill` tool from any agent, which is genuinely more ergonomic than shelling out.
- [ ] B20. **CUT. Dropped `omf-setup` skill.** User said no launcher wrappers. The `scripts/install.sh` script is sufficient; no guided skill wrapper.

### Phase C — Agents

- [ ] C1. **Rewrite ALL 31 existing agents** with the verified frontmatter schema (Ground Truth section). For each agent:
  - Quote `id` value
  - Drop `tier` field entirely
  - Add explicit `reasoning.enabled` where appropriate
  - Fix `tools:` to use canonical forge tool names
  - Add `user_prompt` matching the built-in agents' pattern (for event + date injection)
  - Rewrite body using XML-tagged sections: `<Role>`, `<Success_Criteria>`, `<Investigation_Protocol>`, `<Tool_Usage>`, `<Output_Format>`, `<Failure_Modes_To_Avoid>`, `<Examples>`, `<Final_Checklist>` (when appropriate for the agent — short agents don't need all sections)
  - Remove any Claude-specific mentions
  - Ensure the description is thorough — it's the primary trigger mechanism for delegation
- [ ] C2. **Add agent: `critic`**. Source: `oh-my-claudecode/agents/critic.md` (273 lines, heavyweight). Multi-perspective plan/code reviewer with pre-commitment predictions, verification, adversarial escalation. Read-only tools.
- [ ] C3. **Add agent: `analyst`**. Source: `oh-my-claudecode/agents/analyst.md`. Pre-planning consultant for requirements analysis. Complements `muse` (which plans) by gathering requirements first.
- [ ] C4. **Add agent: `verifier`**. Source: `oh-my-claudecode/agents/verifier.md` + `oh-my-codex/prompts/verifier.md`. Evidence-based completion checker. Read+shell tools (can run tests).
- [ ] C5. **Add agent: `explorer`**. Source: `oh-my-claudecode/agents/explore.md` + `oh-my-codex/prompts/explore.md`. Codebase search specialist — complements `sage` by being more tactical (sage is broad research, explorer is targeted file-finding).
- [ ] C6. **Add agent: `tracer`**. Source: `oh-my-claudecode/agents/tracer.md`. Evidence-driven causal tracing with competing hypotheses + uncertainty tracking.
- [ ] C7. **Add agent: `qa-tester`**. Source: `oh-my-claudecode/agents/qa-tester.md`. Interactive CLI testing specialist. Uses `shell` + `task` tools.
- [ ] C8. **Add agent: `code-simplifier`**. Source: `oh-my-claudecode/agents/code-simplifier.md`. Simplifies recently modified code for clarity/consistency without changing behavior.
- [ ] C9. **Add agent: `document-specialist`**. Source: `oh-my-claudecode/agents/document-specialist.md`. External documentation & reference specialist. Read-only.
- [ ] C10. **Add agent: `git-master`**. Source: `oh-my-claudecode/agents/git-master.md`. Atomic commits, rebasing, history management, commit trailer protocol enforcement.

### Phase D — Catalog, Docs, Doctor

(Note: some v1-draft doc files have been consolidated after critical review.)

- [ ] D1. **Create `catalog-manifest.json`** at repo root. Schema based on `oh-my-codex/templates/catalog-manifest.json` but simpler:
  ```json
  {
    "$schema": "./catalog-manifest.schema.json",
    "schemaVersion": 1,
    "catalogVersion": "2026.04.09",
    "name": "oh-my-forge",
    "description": "...",
    "agents": [
      { "id": "architect", "path": "agents/core/architect.md", "category": "core", "status": "active", "core": true, "reasoning": true }
    ],
    "skills": [
      { "name": "autopilot", "path": "skills/autopilot/SKILL.md", "category": "execution", "status": "active", "core": true }
    ],
    "commands": [
      { "name": "scaffold", "path": "commands/scaffold.md", "category": "workflow" }
    ],
    "templates": [
      { "name": "forge-doom-loop-reminder", "path": "templates/forge-doom-loop-reminder.md" }
    ]
  }
  ```
  Include EVERY file shipped by oh-my-forge. This is the single source of truth for the install/doctor/uninstall scripts.
- [ ] D2. **Create `catalog-manifest.schema.json`** — JSON Schema validating the manifest shape. Keep it simple; used only for editor autocomplete and CI validation.
- [ ] D3. **Rewrite `README.md`** from scratch. Target information architecture:
  - Title + tagline + warning banner about v2 rewrite + migration note
  - TL;DR code block
  - Quick Start (install + first-session)
  - What's in the box (3-column table: agents / skills / commands with counts)
  - Execution modes explanation (skills as execution modes)
  - Agent interface map (table)
  - Skill interface map (table)
  - Command interface map (table)
  - Configuration (pointing at `.forge.toml`, `.mcp.json`, `AGENTS.md`)
  - Template customization (the Handlebars override story) — inline section, not separate file
  - Commit trailer protocol — inline reference, full spec in AGENTS.md
  - Keyword routing cheat sheet (from E1) — inline table
  - Design systems (keep existing shadcn/radix/base-ui docs)
  - Troubleshooting (symptom → command table)
  - Doctor + Uninstall
  - Relationship to other oh-my-* projects
  - License
  - Credits
- [ ] D4. **Rewrite `docs/AGENTS.md`** to reflect forgecode's actual agent model (no fake tiers, real tool names, correct delegation patterns). Include ADR-style explanation of why oh-my-forge does NOT use `tier` field. This is the **internal documentation for contributors**, distinct from the repo-root `AGENTS.md` which is the **user-facing forgecode auto-loaded rules file**.
- [ ] D5. **Create `docs/REFERENCE.md`** — CONSOLIDATED reference that covers skills, commands, and templates in one file. Sections:
  - `## Skills` — the 2-field frontmatter rule, `skill` tool invocation, description-as-trigger principle, bundled resources (`scripts/`, `references/`, `assets/`), XML-tagged body convention, authoring a new skill, progressive disclosure pattern
  - `## Commands` — command file format, `{{parameters}}` body variable, `/name` REPL invocation, authoring a new command
  - `## Templates` — every override-able Handlebars template from `~/forge/templates/`, example override, Handlebars context variables
  - `## Tools` — canonical tool name list with 1-line purpose each
- [ ] D6. **CUT. Merged into D5.** Originally `docs/SKILLS.md`.
- [ ] D7. **CUT. Merged into D5.** Originally `docs/TEMPLATES.md`.
- [ ] D8. **Create `docs/CONFIGURATION.md`** — the full `.forge.toml` reference with every top-level key, every section, valid values, and recommended defaults. Derived from `forge.schema.json` but human-readable. Keep this as a separate file because it's the longest reference doc.
- [ ] D9. **CUT. Merged into D5's `## Commands` and the README's Troubleshooting section.** Originally `docs/COMMANDS.md`.
- [ ] D10. **Create `docs/MCP.md`** — how to set up MCP servers: `~/forge/.mcp.json` shape, `forge mcp import/list/show/remove/reload/login/logout` subcommands, common servers to configure (emacs, github, filesystem, fetch, puppeteer). Keep separate because MCP is its own ecosystem.
- [ ] D11. **Rewrite `docs/CONTRIBUTING.md`** to explain: how to add a new agent (catalog-manifest + file), how to add a new skill (catalog-manifest + directory), how to add a new command, how to add a template override, how to run the doctor script, how to cut a release using the `release` skill.
- [ ] D12. **Create `CHANGELOG.md`** with this v2 rewrite as the first entry. Document every breaking change (the `forge.yaml` → `.forge.toml` switch is the #1 breaking change). Reference `scripts/migrate-from-v1.sh`.
- [ ] D13. **Create `plans/README.md`** explaining the `plans/` directory convention and the forgecode plan format.

### Phase E — Injection Seams, Commands, Routing

- [ ] E1. **Add keyword-routing table** to `AGENTS.md`. Format: a markdown table mapping natural-language triggers → skill name → behavior. Rows: "ralph / don't stop / must complete" → `ralph` skill. "autopilot / build me / handle it all" → `autopilot` skill. "plan / strategy / design" → `plan` skill. "debug / trace / root cause" → `tracer` skill. Etc. ~15 rows. This is pure prose read by the LLM at each turn; no code needed.
- [ ] E2. **Add marker-bounded injection seams** to the top 5 agents (forge/executor, architect, critic, verifier, code-reviewer). Use format:
  ```
  <!-- OMF:GUIDANCE:<AGENT>:<SECTION>:START -->
  ...customizable content...
  <!-- OMF:GUIDANCE:<AGENT>:<SECTION>:END -->
  ```
  Sections: CONSTRAINTS, TOOLS, OUTPUT_FORMAT. Users can patch the content between markers without editing the agent file structure, and an `omf-update` script (Phase E7) can re-sync updates while preserving user customizations.
- [ ] E3. **Add lore commit trailer protocol** to `AGENTS.md`. Structured git trailers:
  ```
  Constraint: <what constrained this decision>
  Rejected: <alternative> | <why rejected>
  Confidence: high|medium|low
  Scope-risk: low|medium|high
  Directive: <if user gave an explicit order>
  Tested: <what was tested>
  Not-tested: <what wasn't>
  Co-Authored-By: ForgeCode <noreply@forgecode.dev>
  ```
  Reference: `oh-my-claudecode/CLAUDE.md:67-95`, `oh-my-codex/templates/AGENTS.md:58-125`.
- [ ] E4. **Create `commands/` directory** with slash-command files. Port the `[[commands]]` from the existing `forge.yaml` into individual files under `commands/`:
  - `commands/scaffold.md`
  - `commands/feature.md`
  - `commands/bugfix.md`
  - `commands/review.md`
  - `commands/refactor.md`
  - `commands/test.md`
  - `commands/document.md`
  - `commands/secure.md`
  - `commands/perf.md`
  - `commands/deploy.md`
  - `commands/migrate.md`
  - `commands/api.md`
  - `commands/schema.md`
  - `commands/cleanup.md`
  - `commands/estimate.md`
  Each uses the verified command frontmatter (`description`, optional `name`) and body uses Handlebars `{{parameters}}`. No `value:` field — that was a v1 plan error. Do NOT inline `[[commands]]` in `.forge.toml`; ship as files for discoverability.
- [ ] E5. **Add stage-gated team pipeline commands**. Port from `oh-my-gemini-cli/commands/omg/team-*.toml`. Commands:
  - `commands/team-assemble.md` — select the team roster based on task shape
  - `commands/team-plan.md` — invoke `muse` agent to write the plan (pre-condition: must have interview state)
  - `commands/team-prd.md` — invoke `analyst` agent to write the PRD
  - `commands/team-exec.md` — invoke `forge` (or executor agent) to execute plan (pre-condition: team-plan + team-prd artifacts exist)
  - `commands/team-verify.md` — invoke `verifier` + `critic` agents
  - `commands/team-fix.md` — invoke `forge` to address verify issues; loops to team-verify
  - `commands/team-status.md` — show current stage and pending artifacts
  Each command has pre-condition checks (reads `.forge/state/team/*.json`) and writes a next-stage hint on completion.
- [ ] E6. **Ship template overrides** in `templates/` directory. Create the following overrides that will be copied to `~/forge/templates/` by the install script:
  - `forge-doom-loop-reminder.md` — stronger loop-breaking reminder with oh-my-forge's recommended tactics (switch to sage for re-investigation, re-decompose the task, swap strategies)
  - `forge-pending-todos-reminder.md` — smarter todo reminder that references the plan file if one is active
  - `forge-partial-skill-instructions.md` — enhanced skill catalog injection that lists oh-my-forge skills with clearer triggering guidance
  Each file has a leading comment explaining it's an override and linking to the built-in for comparison.
- [ ] E7. **Write `scripts/omf-update.sh`** — script that updates oh-my-forge in place, preserving user customizations within the marker-bounded sections (Phase E2). Uses `perl -pe` (or `sed`) to surgically replace content outside `<!-- OMF:...:START -->`/`<!-- OMF:...:END -->` markers while preserving what's inside. Based on `oh-my-claudecode/scripts/setup-claude-md.sh:252-286` pattern. Bash 5.3+ style.
- [ ] E8. **Add `FORGE_KEYWORDS.md`** in docs/ — comprehensive cheat sheet listing every keyword trigger, every skill, every command, every agent, with a one-line "use this when" hint for each. Single-page reference. Link from README.
- [ ] E9. **Add ONE `examples/` starter**. Keep the existing `examples/laravel-vue/README.md` as-is (it's untouched legacy). Do NOT add multiple new starters (reviewer cut: `examples/nextjs/`, `examples/rust/`, `examples/python/` are scope creep). If a single fresh example is valuable, add just `examples/nextjs/` — 5-10 files max, showing `.forge/` project overrides, `.mcp.json` example, and a minimal `AGENTS.md`. Defer rust/python starters to v2.
- [ ] E10. **Add `.editorconfig` and `.gitattributes`**. Inline the target values so the executor doesn't need to cross-reference another repo. Minimum contents:
  - `.editorconfig`:
    ```
    root = true
    [*]
    end_of_line = lf
    insert_final_newline = true
    charset = utf-8
    trim_trailing_whitespace = true
    indent_style = space
    [*.{md,toml,yaml,yml,json}]
    indent_size = 2
    [*.sh]
    indent_size = 2
    [Makefile]
    indent_style = tab
    ```
  - `.gitattributes`:
    ```
    * text=auto eol=lf
    *.sh text eol=lf
    *.md text eol=lf
    ```
- [ ] E11. **CUT. Deferred to v2.** Originally GitHub workflows (doctor, shellcheck, validate-manifest) and issue templates. Repo hygiene, but not "aggressive rewrite" work — will be added in a follow-up plan after the core v2 content is stable. The doctor script and shellcheck can still be run manually.

### Phase F — Verification (the plan executor runs these before claiming done)

- [ ] F0. **PRE-FLIGHT SMOKE TEST**: Before mass-rewriting all 31 agents and 20 skills, do a single end-to-end smoke run. Pick ONE agent (`architect`) and ONE skill (`plan`) and fully rewrite them following the plan. Then install them into a temp project, run `forge list agent` and `forge list skill`, verify they appear. If this fails, STOP and re-read Ground Truth before continuing. Only after the smoke test succeeds should the bulk rewrite (A5, B1, C1) proceed.
- [ ] F1. **Run `scripts/doctor.sh`**. Must exit 0. Fix any failures discovered.
- [ ] F2. **Run `shellcheck` on every script in `scripts/`**. Zero warnings. If shellcheck is not installed, document the expectation and skip with a warning.
- [ ] F3. **Validate `catalog-manifest.json`** against `catalog-manifest.schema.json` using `jq`. Must parse and every path must exist on disk.
- [ ] F4. **Parse every agent file** using `yq` (or `python3 -c "import yaml,sys; ..."` as fallback). Every frontmatter must have `id`, `title`, `description`, and `tools`. No `tier` field should remain. No `max_walker_depth` field should remain. Every tool name in every `tools:` list must be in the canonical tool name set (`task`, `sem_search`, `fs_search`, `read`, `write`, `undo`, `remove`, `patch`, `multi_patch`, `shell`, `fetch`, `skill`, `todo_write`, `todo_read`, `plan`, `followup`, `mcp_*`) OR a valid agent id that is also shipped by oh-my-forge (dynamically checked — load all agent ids first, then cross-reference).
- [ ] F5. **Parse every skill file** using `yq`. Frontmatter must have `name` and `description`. Extra fields are allowed but should be flagged as a soft warning (and not present in any file that oh-my-forge ships).
- [ ] F6. **Parse every command file** using `yq`. Frontmatter must have `description`. `name` is optional but recommended. There should be NO `value` field (that was a v1 plan error). The body should use `{{parameters}}`, not `{{args}}`.
- [ ] F7. **Validate `.forge.toml`** using `python3 -c "import tomllib; tomllib.load(open('.forge.toml','rb'))"` or `toml-cli`. Must parse. Then grep-check that `[updates] frequency` is one of `daily|weekly|always`.
- [ ] F8. **Validate `.mcp.json.example`** using `jq . < .mcp.json.example`. Must parse as valid JSON.
- [ ] F9. **Install in a temp dir test**: create `/tmp/omf-test-<timestamp>`, run `./scripts/install.sh --project /tmp/omf-test-<timestamp>`, verify `/tmp/omf-test-<timestamp>/.forge/agents/` exists with files, `/tmp/omf-test-<timestamp>/.forge/skills/` exists with files, `/tmp/omf-test-<timestamp>/.mcp.json` exists, BUT `/tmp/omf-test-<timestamp>/AGENTS.md` does NOT exist (since `--with-agents-md` was not passed). Clean up afterward.
- [ ] F10. **Grep for forbidden strings** across the whole repo (excluding `plans/` historical files):
  - no `forge.yaml` references (except in CHANGELOG migration notes and migrate-from-v1.sh)
  - no `~/.forge/` (leading dot on global)
  - no `tier: fast|standard|complex` in any agent frontmatter
  - no `net_fetch`, `skill_fetch` in skill/agent bodies
  - no `{{args}}` in command bodies (must be `{{parameters}}`)
  - no `value:` field in command frontmatter
  - no `max_walker_depth:` field in agent frontmatter
  - no `updates.frequency` values other than `daily|weekly|always` in `.forge.toml` or docs examples
- [ ] F11. **Check README links**. All relative markdown links must resolve to real files in the repo. Use `grep -rn '](' README.md docs/` and verify each target exists.
- [ ] F12. **Run `forge list agent`, `forge list skill`, `forge list cmd`** (if `forge` binary is available after installing oh-my-forge to `~/forge/` via the install script in a test user profile). Soft check — emits a warning if `forge` is not available but does not fail.
- [ ] F13. **RUNTIME SMOKE TEST** (new, strongest check): If `forge` binary is available, invoke a minimal interaction with one oh-my-forge agent using the CLI: `forge --agent architect -p 'say hello, 10 words max'`. Success = non-zero output, no stderr errors about unknown tool names or malformed frontmatter. Soft check if `forge` unavailable.
- [ ] F14. **Final summary**: print a table of (files_added, files_modified, files_deleted) and a diff count. Tell the user how many agents, skills, commands, templates, and docs are in the final pack. Compare against `catalog-manifest.json`.

## Verification Criteria

- ✅ `forge.yaml` is deleted from the repo (breaking change acknowledged in CHANGELOG).
- ✅ `.forge.toml` at the repo root is valid TOML and matches the verified flat schema.
- ✅ `.mcp.json.example` at the repo root is valid JSON.
- ✅ Every agent file has valid YAML frontmatter with only canonical forge fields (`id`, `title`, `description`, `reasoning`, `tools`, `user_prompt`, optional `model`, `temperature`, etc.) and NO `tier` field and NO `max_walker_depth` field.
- ✅ Every skill file has frontmatter with `name` and `description`. No extra fields (by convention).
- ✅ Every command file has frontmatter with `description` (and optionally `name`). NO `value` field. Body uses `{{parameters}}`, not `{{args}}`.
- ✅ Every tool name used in every agent's `tools:` list is in the canonical forgecode tool set OR is a valid shipped agent id.
- ✅ Install script targets `~/forge/` (no leading dot on global) and `./.forge/` (with leading dot on project). Does NOT copy `AGENTS.md` by default.
- ✅ Doctor script exits 0 when run against a fresh install.
- ✅ `catalog-manifest.json` is valid, cross-refs every shipped file, and every shipped file is in the manifest.
- ✅ `README.md` accurately describes what's shipped, gives working quick-start commands, and never references `forge.yaml` or `~/.forge/` anywhere (except in CHANGELOG migration notes).
- ✅ Repo-root `AGENTS.md` is auto-loadable by forgecode (plain markdown, no broken directives).
- ✅ All shell scripts pass `shellcheck` cleanly.
- ✅ F0 pre-flight smoke test passes before mass rewrite begins.
- ✅ Phase F verification tasks all pass.

## Potential Risks and Mitigations

1. **Tool-name drift between forgecode versions.** If forgecode renames a tool in a future release, every agent's `tools:` list becomes wrong.
   Mitigation: `scripts/doctor.sh` checks every agent's tool list against the canonical set. Document in CONTRIBUTING.md how to update when forgecode renames tools.

2. **Schema drift between `forge.schema.json` and the actual parser.** The schema claims top-level keys that don't exist in real installs (e.g., the research report said `[tools.patch]` but live installs use top-level `max_search_lines`).
   Mitigation: We ship a `.forge.toml` that matches the LIVE `~/forge/.forge.toml` structure, not the schema's theoretical structure. Tested by parsing with the actual forgecode binary in F12/F13.

3. **Users still have `forge.yaml` from the v1 pack.** Deleting our `forge.yaml` doesn't delete theirs. Their `~/forge/forge.yaml` will just silently not be loaded.
   Mitigation: New task A9 (`scripts/migrate-from-v1.sh`) detects stray v1 files and offers cleanup. Install script A6 prints a warning on detection. CHANGELOG has an explicit breaking-change entry with migration steps.

4. **Breaking agents that users depended on.** Rewriting all 31 existing agents could break downstream user workflows that reference specific agent text.
   Mitigation: Keep all existing agent `id`s stable. Keep the behavior description similar. Only rewrite the body for quality, and use the marker-bounded injection seams (E2) so users can re-customize their own content.

5. **Skill frontmatter cleanup is cosmetic not functional.** Stripping `argument-hint`, `level`, `aliases` from skills does not fix any bug — forgecode silently ignores them. The cleanup is for consistency and future-proofing, not correctness.
   Mitigation: Document the removal in CHANGELOG as a consistency change, not a bugfix.

6. **Mis-stating forgecode behavior due to stale research.** The original reconnaissance reports had several errors. The review found 8 more in v1 of this plan.
   Mitigation: The Ground Truth section of this plan (as of v1-reviewed) captures verified-against-source facts with inline source citations. The executing agent MUST treat Ground Truth as canonical and STOP to ask if anything seems contradictory.

7. **Scope creep during execution.** 80+ tasks is a lot. It's tempting to keep adding.
   Mitigation: All additions go in a v2 plan file. If something seems obviously missing, the executor stops and asks the user, does NOT silently add it.

8. **Commands ported wholesale from old `forge.yaml` may be low-quality.** The inline commands in the old `forge.yaml` are decent but not great.
   Mitigation: E4 is a port, not a rewrite. Quality improvements are a follow-up plan. Ship the port first. Strip all `value:` and `{{args}}` references during the port.

9. **The `tier: fast|standard|complex` removal** loses useful "model routing" information that users had.
   Mitigation: Preserve intent via per-agent `reasoning.enabled`, per-agent `model`, and per-agent `max_requests_per_turn` where appropriate. Document the mapping in `docs/AGENTS.md` (D4).

10. **MCP examples may reference servers the user doesn't have installed.** Shipping `.mcp.json.example` with non-working defaults is worse than not shipping.
    Mitigation: `.mcp.json.example` ships with every server commented out by default and one `// TODO: uncomment and configure` on each. The install script copies it as `.mcp.json` only if no existing one (`cp -n`), so users have to explicitly enable.

11. **Template override fragility (E7 `omf-update.sh`).** The marker-bounded merge logic is brittle with multi-line markers, nested markers, and line endings.
    Mitigation: E7 uses explicit per-line marker detection (not multi-line regex), enforces LF-only line endings, and has a `--dry-run` mode as the first use. Before shipping, test the merge logic against synthetic edge cases (no markers, one set, two nested sets, CRLF input, empty content between markers).

12. **Task-description vagueness in Phase B/C.** Some port tasks reference "(implicit — implemented as an agent there)" which means the executor has to synthesize from scratch, not port.
    Mitigation: Task labels now include `[PORT]` for direct ports and `[SYNTHESIZE]` for items requiring synthesis. Executor should budget 3-5× more time for SYNTHESIZE tasks.

13. **Python3.11+ dependency in doctor script.** Python's `tomllib` is Python 3.11+. Older systems may not have it.
    Mitigation: Doctor script has three-tier validation: `toml-cli` > `python3 tomllib` > grep-syntax-check. Documents the fallback chain.

14. **`execute-plan` skill behavior with 70+ tasks.** The skill commits to completing ALL tasks before exiting. A single fundamental blocker (e.g., forgecode schema change) could bring execution to a halt.
    Mitigation: F0 pre-flight smoke test catches fundamental schema mismatches before bulk work starts. Individual task failures become `[!] FAILED` with reason and execution continues. Plan is still organized so phases A/B/C/D/E/F have clean boundaries and can be resumed mid-phase.

## Alternative Approaches

1. **Minimal fix (Conservative scope)**. Just fix Phase A + B1 (the critical brokenness). ~20 files changed. Trade-off: leaves oh-my-forge still sparse relative to the reference codebases; no new value added.

2. **Plan-less direct execution**. Skip writing a plan file and just start editing. Trade-off: no checkpointing, no sub-agent review step, hard to resume, invisible progress. Rejected because user explicitly asked for plan-first.

3. **Replace oh-my-forge entirely with a thin wrapper that installs oh-my-codex's agents/skills directly**. Trade-off: would get us a ~95% parity package overnight, but: (a) tied to codex's conventions, (b) drags in TypeScript baggage we don't want, (c) loses the ability to add forge-specific features, (d) user asked for oh-my-forge, not a codex shim.

4. **Auto-generate agents from reference codebases via a sync script**. Trade-off: easier updates but harder to customize; introduces a build step we don't want (and the sync script would need to be maintained in some language other than bash, likely).

5. **Port only skills, keep agents as-is**. Trade-off: leaves the #1 bug (wrong tool names in every agent) unfixed. Rejected.

## Execution Notes

- This plan is designed to be executed by the `execute-plan` built-in skill on a `forge` agent with full tool access.
- Every task is independently committable (atomic change).
- Tasks within a phase can be parallelized where they don't touch the same files.
- **Phase A must complete before Phase B/C** (they depend on the fixed foundation).
- **F0 is a hard pre-flight gate** — do not proceed to the bulk rewrites (A5, B1, C1) until F0 passes.
- Phase D depends on A/B/C (docs reference the shipped files).
- Phase E can be interleaved with D.
- Phase F (except F0) is strictly last.
- If any task fails fundamentally (not just a bug to fix), mark it `[!] FAILED` with a one-line reason and continue. The executor should NOT silently skip or downgrade tasks.
- After execution completes (or fails), the final message to the user MUST include:
  - Task completion count (`N completed, M failed`)
  - List of FAILED tasks with reasons
  - A diff summary (files added, modified, deleted)
  - A cheat-sheet of 2-3 next actions the user should take (e.g., "review CHANGELOG.md", "run `scripts/doctor.sh`")

## Post-Execution Checkpoint

After this plan finishes, the user will likely want to:
1. Review the diff before committing (`git diff`)
2. Run `scripts/doctor.sh` to confirm health
3. Run `scripts/install.sh --global --yes` to install into `~/forge/`
4. Test by running `forge --agent architect 'hello'` in a test project
5. Commit the rewrite as a single `feat!:` commit (breaking change) with the CHANGELOG as the commit body
