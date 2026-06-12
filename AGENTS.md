# AGENTS.md — oh-my-forge Project Rules

This file is auto-loaded by forgecode at session start (from `./AGENTS.md` in the
current working directory, and `~/forge/AGENTS.md` for global rules). It defines
the operating contract for AI agents running under the oh-my-forge configuration
pack.

oh-my-forge is a configuration-only pack for [ForgeCode](https://forgecode.dev):
no Rust crates, no Node.js, no wrapper CLI. Agents, skills, commands, and
templates drop into `~/forge/` or `./.forge/` and work.

---

## 1. Forge architecture at a glance

Forge is a multi-agent CLI tool. Every session runs with exactly one *active*
agent; the active agent may delegate work to other agents via the `task` tool.

### Resource layout (verified against forgecode source)

| Resource | Global path | Project-local path | Loader notes |
|---|---|---|---|
| TOML config | `~/forge/.forge.toml` | — (no project-local) | Only global is read. |
| MCP config | `~/forge/.mcp.json` | `./.mcp.json` (CWD root) | Both merged. |
| AGENTS.md | `~/forge/AGENTS.md` | `./AGENTS.md` (CWD root) | Both auto-loaded. |
| Agents | `~/forge/agents/*.md` | `./.forge/agents/*.md` | **Flat only** — subdirectories are NOT walked. |
| Skills | `~/forge/skills/<name>/SKILL.md` | `./.forge/skills/<name>/SKILL.md` | One level deep. Also `~/.agents/skills/` is a third search path. |
| Commands | `~/forge/commands/*.md` | `./.forge/commands/*.md` | **Flat only** — same rule as agents. |
| Templates | `~/forge/templates/*.md` | — (no project-local) | Override built-in Handlebars partials. |

**Precedence (highest first):** project-local > agents-skills (`~/.agents/skills`) > global (`~/forge/`) > built-in.

### Built-in agents

| Agent | Role |
|---|---|
| `forge` | Implementer. Full write/patch/shell/mcp tool set. Default agent. |
| `muse` | Planner. Has the `plan` tool and can delegate to `sage`. |
| `sage` | Researcher. Read-only — no write/patch/shell. |

### Built-in skills

| Skill | Purpose |
|---|---|
| `create-skill` | Guided skill authoring workflow. |
| `execute-plan` | Reads `plans/*.md` and executes `[ ]` markers in-place. |
| `github-pr-description` | Generates PR descriptions from the current diff. |

### Tool catalog (snake_case, case-insensitive in the loader)

```text
task            sem_search      fs_search       read
write           undo            remove          patch
multi_patch     shell           fetch           skill
todo_write      todo_read       plan            followup
mcp_*           <agent_id>      (e.g. sage, forge, muse as delegatable tools)
```

Agents are themselves callable as tools — listing `sage` in an agent's `tools:`
block lets that agent delegate to `sage` via the `task` tool. `mcp_*` exposes
every configured MCP tool.

---

## 2. oh-my-forge resource pack

oh-my-forge adds **40 custom agents**, **46 skills**, and **22 commands** on
top of forgecode's built-ins. See `catalog-manifest.json` for the authoritative
counts and `docs/FORGE_KEYWORDS.md` for the cheat sheet.

### Notable custom agents

Categorization is metadata only (see `catalog-manifest.json`) — the agent files
themselves live **flat** in `agents/` (and get copied flat to `~/forge/agents/`)
because forgecode's agent loader does not walk subdirectories.

| Category | Agents |
|---|---|
| Core | `architect`, `architect-low`, `executor`, `executor-low`, `executor-high`, `planner`, `code-reviewer`, `debugger` |
| Backend | `api-designer`, `auth-specialist`, `db-engineer` |
| Frontend | `designer`, `designer-low`, `ui-engineer`, `style-expert`, `ux-analyst` |
| DevOps | `deploy-engineer`, `infra-planner` |
| Quality | `perf-optimizer`, `security-reviewer`, `test-engineer`, `test-writer` |
| Specialist | `data-modeler`, `dep-auditor`, `doc-writer`, `git-strategist`, `i18n-expert`, `migrator`, `refactorer`, `scientist`, `seo-expert` |
| Added in v2 | `critic`, `analyst`, `verifier`, `explorer`, `tracer`, `qa-tester`, `code-simplifier`, `document-specialist`, `git-master` |

### Notable custom skills

Skills are invoked via the `skill` tool (NOT `skill_fetch`, NOT a prefix
trigger). Each skill is loaded on demand — the model reads the `description`
field and decides whether to invoke.

| Skill | When |
|---|---|
| `plan` | Strategic planning before implementation. Produces `plans/YYYY-MM-DD-<slug>-v<N>.md`. |
| `ralplan` | Consensus planning — planner + architect + critic deliberation. |
| `autopilot` | Autonomous end-to-end execution for well-scoped work. |
| `ralph` | Must-complete execution; does not give up on a task. |
| `ultrawork` / `turbo` / `eco` | Tuned execution modes for quality / speed / cost. |
| `ultragoal` | Durable multi-goal initiative tracked across sessions via a plan file ledger. |
| `team` | Stage-gated multi-agent pipeline. |
| `tracer` | Evidence-driven debugging. |
| `verify` | Evidence-based completion check. |
| `critic` | Final-gate multi-perspective review. |
| `code-review` | Severity-rated diff review (Critical/Major/Minor/Nit) with merge verdict. |
| `security-review` | OWASP Top 10 + secrets + trust-boundary audit with zero-noise bias. |
| `tdd` | Red-green-refactor discipline enforcing the Iron Law: test first, always. |
| `explore` | Read-only codebase exploration (delegates to `sage`). |
| `ai-slop-cleaner` | Regression-safe deletion-first cleanup pass. |
| `cancel` | Clean mode exit with dependency-ordered cleanup. |
| `note` / `recall` / `wiki` / `remember` | Compaction-resilient state and knowledge surfaces. |
| `visual-verdict` | Structured JSON visual diff scoring. |
| `deep-dive` / `deep-interview` | Two-stage discovery pipelines. |
| `skillify` | Extract a reusable skill from the current conversation. |
| `release` | oh-my-forge release flow. |
| `doctor` | Run `scripts/doctor.sh` and interpret the result. |
| `scaffold` / `learner` / `docker` / `tailwind-v4` / `ultraqa` | Task-specific helpers. |
| `ask` | Consult codex, claude, or gemini for a second opinion without leaving the session. |
| `mcp-setup` | Guided workflow for wiring MCP servers into `~/forge/.mcp.json`. |
| `deepinit` | Generate hierarchical AGENTS.md documentation across a codebase. |
| `omf-reference` | In-session reference card for oh-my-forge resource layout and routing. |
| `typescript-pro` | Advanced TypeScript type systems, generics, branded types, tRPC setup. |
| `emacs-integration` | Bidirectional Emacs editor integration via MCP tools. |
| `write-bash` | GNU Bash 5.3+ house style — always active for all shell/Bash work. |
| `use-rg` / `use-fd` / `use-gnu-tools` | House tool preferences — always active (see note below). |
| `karpathy-guidelines` | Anti-overengineering behavioral guidelines — always active. |
| `use-grepai` | Semantic code search via the `grepai` CLI for call graphs and intent search. |

Full list in `catalog-manifest.json`.

---

## 3. Keyword routing cheat sheet

When the user's prompt matches any of these triggers, load the corresponding
skill via the `skill` tool (or activate the corresponding agent via `task`).
Match on substrings, case-insensitive.

| Trigger (in user prompt) | Load skill | Why |
|---|---|---|
| "plan", "let's plan", "strategy", "design this" | `plan` | Structured planning before code. |
| "ralplan", "consensus plan", "deliberate", "high-risk plan" | `ralplan` | Multi-perspective plan deliberation. |
| "ralph", "don't stop", "must complete", "finish this no matter what" | `ralph` | Must-complete execution loop. |
| "autopilot", "build me", "handle it all", "end-to-end" | `autopilot` | Autonomous end-to-end execution. |
| "ultrawork", "deep focus" | `ultrawork` | Parallel high-quality execution. |
| "turbo", "go fast", "prototype it" | `turbo` | Speed-over-quality mode. |
| "eco", "cost", "cheap mode" | `eco` | Cost-conscious execution. |
| "debug", "trace", "root cause", "why is X broken" | `tracer` | Evidence-driven debugging. |
| "verify", "is this done", "double check", "did it work" | `verify` | Evidence-based completion check. |
| "critic", "review this plan", "red team it" | `critic` | Multi-perspective critique. |
| "explore", "where is", "find X in this codebase" | `explore` | Read-only exploration via sage. |
| "cleanup", "deslop", "remove dead code" | `ai-slop-cleaner` | Deletion-first cleanup. |
| "cancel", "stop cleanly", "exit mode" | `cancel` | Clean mode exit. |
| "note", "remember this", "save for later" | `note` | Compaction-resilient notepad. |
| "recall", "what did we decide about", "look up our state" | `recall` | State-first search. |
| "wiki", "document this concept" | `wiki` | Persistent markdown KB. |
| "release", "cut a version", "bump version" | `release` | Release flow. |
| "doctor", "is oh-my-forge healthy", "omf-doctor" | `doctor` | Health check. |
| "visual check", "screenshot diff", "looks right?" | `visual-verdict` | Visual regression scoring. |
| "make a skill", "extract skill from this session" | `skillify` | Skill extraction. |
| "team", "assemble the team", "staged pipeline" | `team` | Stage-gated team pipeline. |
| "review this diff", "code review", "review my changes" | `code-review` | Severity-rated diff quality gate. |
| "security audit", "OWASP", "check for vulnerabilities", "secrets check" | `security-review` | OWASP + secrets scan. |
| "tdd", "test first", "red-green", "write the test first" | `tdd` | Test-first discipline. |
| "second opinion", "ask codex", "ask gemini", "cross-check this" | `ask` | Multi-model consultation. |
| "set up mcp", "add mcp server", "configure context7", "wire up mcp" | `mcp-setup` | MCP server wiring. |
| "deepinit", "init the codebase docs", "generate AGENTS.md", "document this project for agents" | `deepinit` | Hierarchical AGENTS.md generation. |
| "ultragoal", "multi-goal initiative", "track goals across sessions", "goal ledger" | `ultragoal` | Durable multi-session goal tracking. |
| "omf reference", "how does oh-my-forge work", "what skills are available" | `omf-reference` | oh-my-forge reference card. |
| "emacs", "open in emacs", "emacs diagnostics" | `emacs-integration` | Emacs MCP editor integration. |
| "grepai", "call graph", "semantic search", "who calls" | `use-grepai` | Semantic codebase search. |
| "typescript types", "tRPC", "advanced generics", "branded types" | `typescript-pro` | Advanced TypeScript type patterns. |
| "bash", "shell script", "write a script" | `write-bash` | GNU Bash 5.3+ house style. |

**House preference skills** — `use-rg`, `use-fd`, `use-gnu-tools`, and `karpathy-guidelines` are standing preferences that apply automatically to all shell commands and code work. They do not need explicit invocation — forge loads them at the start of every relevant task.

This table is **prose read by the LLM each turn** — it is not a code-enforced
router. Keywords are heuristics; the model may override based on context.

---

## 4. Lore Commit Protocol

Every commit message should follow the Lore protocol — structured decision
records using native git trailers. Commits are not just labels on diffs; they
are the atomic unit of institutional knowledge.

### Format

```text
<intent line: why the change was made, not what changed>

<body: narrative context — constraints, approach rationale>

Constraint: <external constraint that shaped the decision>
Rejected: <alternative considered> | <reason for rejection>
Confidence: <low|medium|high>
Scope-risk: <narrow|moderate|broad>
Directive: <forward-looking warning for future modifiers>
Tested: <what was verified (unit, integration, manual)>
Not-tested: <known gaps in verification>
Co-Authored-By: ForgeCode <noreply@forgecode.dev>
```

### Trailer vocabulary

| Trailer | Purpose |
|---|---|
| `Constraint:` | External constraint that shaped the decision |
| `Rejected:` | Alternative considered and why it was rejected |
| `Confidence:` | Author's confidence level (low/medium/high) |
| `Scope-risk:` | How broadly the change affects the system (narrow/moderate/broad) |
| `Reversibility:` | How easily the change can be undone (clean/messy/irreversible) |
| `Directive:` | Forward-looking instruction for future modifiers |
| `Tested:` | What verification was performed |
| `Not-tested:` | Known gaps in verification |
| `Related:` | Links to related commits, issues, or decisions |
| `Co-Authored-By:` | Attribution to the AI agent (ForgeCode) |

### Rules

1. **Intent line first.** The first line describes *why*, not *what*. The diff already shows what changed.
2. **Trailers are optional but encouraged.** Use the ones that add value; skip the ones that don't.
3. **`Rejected:` prevents re-exploration.** If you considered and rejected an alternative, record it so future agents don't waste cycles re-discovering the same dead end.
4. **`Directive:` is a message to the future.** Use it for "do not change X without checking Y" warnings.
5. **`Constraint:` captures external forces.** API limitations, policy requirements, upstream bugs — things not visible in the code.
6. **`Not-tested:` is honest.** Declaring known verification gaps is more valuable than pretending everything is covered.
7. **All trailers use git-native trailer format** (key-value after a blank line). No custom parsing required.

### Example

```text
Prevent silent session drops during long-running operations

The auth service returns inconsistent status codes on token
expiry, so the interceptor catches all 4xx responses and
triggers an inline refresh.

Constraint: Auth service does not support token introspection
Constraint: Must not add latency to non-expired-token paths
Rejected: Extend token TTL to 24h | security policy violation
Rejected: Background refresh on timer | race condition with concurrent requests
Confidence: high
Scope-risk: narrow
Directive: Error handling is intentionally broad (all 4xx) — do not narrow without verifying upstream behavior
Tested: Single expired token refresh (unit)
Not-tested: Auth service cold-start > 500ms behavior
Co-Authored-By: ForgeCode <noreply@forgecode.dev>
```

---

## 5. Working agreements

- **Ground in reality.** Verify claims against the codebase before asserting.
  Never invent file paths, module names, or APIs.
- **Delegate to sub-agents** via the `task` tool for independent parallel
  subtasks — exploration to `sage`, planning to `muse`, deep review to `critic`.
- **Prefer editing** existing files over creating new ones. Prefer deletion
  over addition. Keep diffs small, reviewable, reversible.
- **No new dependencies** without explicit request.
- **Run lint, typecheck, tests** after changes. Don't declare work done until
  the evidence supports the claim.
- **Final reports must include:** changed files, what was verified, remaining risks.

---

## 6. Execution modes are SKILLS (not prefix triggers)

oh-my-forge does NOT use prefix-triggered modes (no `ralph:` or `plan:` prefix
invocation). Every execution mode is a **skill** that lives at
`skills/<name>/SKILL.md` and is invoked via forgecode's `skill` tool. The
model decides when to invoke based on the skill's `description` field and
the keyword routing cheat sheet above.

This is a fundamental difference from oh-my-claudecode — forgecode has no
hook API and no prefix router. The `skill` tool + well-written descriptions
are the routing mechanism.

---

## 7. Configuration

- **`.forge.toml`** — top-level knobs, provider/model, retry, reasoning.
  See `docs/CONFIGURATION.md` for every field.
- **`.mcp.json`** — MCP server configuration. See `docs/MCP.md`.
- **`AGENTS.md`** — this file. Project rules, auto-loaded.
- **`agents/*.md`** — custom agents. Flat layout only.
- **`skills/<name>/SKILL.md`** — custom skills, one subdirectory per skill.
- **`commands/*.md`** — custom slash commands. Flat layout only.
- **`templates/*.md`** — Handlebars template overrides.

For per-agent customization (provider, model, tools, reasoning, temperature),
edit the agent's frontmatter directly. There is no `[agent.<id>]` section in
`.forge.toml`.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| Custom agent doesn't show in `forge list agent` | Check it's flat in `~/forge/agents/` (not in a subdirectory). |
| Skill doesn't load | Check `~/forge/skills/<name>/SKILL.md` exists and has `name` + `description` in frontmatter. |
| Command doesn't show in `/` menu | Check `~/forge/commands/<name>.md` (flat, not nested) and that the body uses `{{parameters}}` not `{{args}}`. |
| `forge.yaml` present | Delete it — v1 artifact, ignored by forgecode. Run `scripts/migrate-from-v1.sh`. |
| `.forge.toml` fails to parse | Check `[updates] frequency` is one of `daily |
|`forge list agent` shows nothing custom | Project-local agents live at `./.forge/agents/*.md`, not`./agents/*.md`. Check the path. |

Run `scripts/doctor.sh` for a full health check.
