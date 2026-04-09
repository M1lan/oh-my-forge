# oh-my-forge

> A v2 ForgeCode (`forge`) workbench -- 40 specialist agents, 30 skills, 15 commands, MCP-ready, doctor-validated.

[![version](https://img.shields.io/badge/catalog-2026.04.09-blue)](./catalog-manifest.json) [![forge](https://img.shields.io/badge/forge-%E2%89%A52.5.2-green)](https://forgecode.dev/) [![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

---

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/<you>/oh-my-forge/main/scripts/install.sh | bash

# Or locally from a clone
git clone https://github.com/<you>/oh-my-forge && cd oh-my-forge && scripts/install.sh

# First session
cd ~/your-project
forge "plan: add user auth with refresh tokens"
```

---

## What this is

**oh-my-forge** is a curated content pack for the [ForgeCode](https://forgecode.dev/) CLI (`forge`). It ships:

- **40 specialist agents** covering core implementation, architecture, review, testing, backend, frontend, DevOps, and specialist domains.
- **30 skills** including execution modes (`autopilot`, `ralph`, `turbo`), planning workflows (`plan`, `ralplan`), QA (`verify`, `critic`, `visual-verdict`), investigation (`explore`, `deep-dive`, `tracer`), knowledge management (`note`, `recall`, `wiki`, `remember`), and meta workflows (`skillify`, `doctor`, `release`).
- **15 slash commands** for common workflows (scaffold, feature, bugfix, review, refactor, test, document, deploy, etc.).
- **Template overrides** for forge's built-in Handlebars prompts (stronger doom-loop breaker, smarter todo reminders).
- **A doctor script** that validates your install.
- **An installer** that safely copies files into `~/forge/` and/or `.forge/` in a project.

## What this is not

- Not a fork of `forge`. We only add content files. `forge` itself is unchanged.
- Not a framework. You can adopt individual pieces without buying in to everything.
- Not a replacement for `forge list`, `forge mcp`, `forge update`. Those still work exactly as documented.

## Quick start

### 1. Install forge

```bash
# See https://forgecode.dev/ for current install instructions
# Expected: `forge --version` shows 2.5.2 or newer
forge --version
```

### 2. Install oh-my-forge content

```bash
git clone https://github.com/<you>/oh-my-forge.git
cd oh-my-forge

# User-global install (populates ~/forge/)
scripts/install.sh

# Or project-local install (populates .forge/ in target project)
scripts/install.sh --project ~/my-project

# Or dry-run first to see what will happen
scripts/install.sh --dry-run
```

The installer is idempotent, respects existing files (use `--overwrite` to force), and backs up any existing `~/forge/.forge.toml`.

### 3. Verify the install

```bash
scripts/doctor.sh --user      # check ~/forge/
scripts/doctor.sh --project . # check the current project's .forge/
```

### 4. First session

```bash
forge "plan: add a /health endpoint to the API"
```

---

## What's in the box

| Category | Count | Examples |
|---|---|---|
| Agents | 40 | `architect`, `executor`, `critic`, `tracer`, `verifier`, `code-reviewer`, `api-designer`, `git-master`, `qa-tester`, ... |
| Skills | 30 | `plan`, `ralplan`, `autopilot`, `ralph`, `turbo`, `verify`, `critic`, `explore`, `deep-dive`, `tracer`, `doctor`, ... |
| Commands | 15 | `/scaffold`, `/feature`, `/bugfix`, `/review`, `/refactor`, `/test`, `/document`, `/deploy`, `/migrate`, ... |
| Templates | 3 | `forge-doom-loop-reminder`, `forge-pending-todos-reminder`, `forge-partial-skill-instructions` |

See [`catalog-manifest.json`](./catalog-manifest.json) for the complete, machine-readable inventory.

## Execution modes (skills as modes)

oh-my-forge exposes **execution modes as skills**. Invoke them by asking for them naturally -- the `description` field in each skill's frontmatter is how forge routes your request.

| Mode | Skill | When to use |
|---|---|---|
| Autopilot | `autopilot` | Full autonomous run from idea to working code. Complex tasks. |
| Ralph (persist) | `ralph` | Keep going until verified complete. Loops with verification. |
| Team | `team` | Multi-agent parallel execution with explicit handoffs. |
| Turbo | `turbo` | Maximum parallel throughput, no confirmations, known tasks. |
| Eco | `eco` | Lightweight single-file edits with minimal ceremony. |
| Ultrawork | `ultrawork` | Maximum parallel throughput across independent subtasks. |
| UltraQA | `ultraqa` | Test/fix cycling until the suite is green. |

Plus planning-first modes:

| Mode | Skill | When to use |
|---|---|---|
| Plan | `plan` | Strategic planning workflow -> writes `plans/YYYY-MM-DD-<slug>-v1.md`. |
| Ralplan | `ralplan` | Consensus planning with planner + architect + critic deliberation. |
| Deep interview | `deep-interview` | Socratic requirements clarification before any code. |

## Agent catalog (highlights)

| Agent | Reasoning | Category | Purpose |
|---|---|---|---|
| `architect` | yes | core | System design, architectural decisions, tradeoffs. |
| `executor` | no | core | Balanced implementation agent. |
| `executor-high` | yes | core | Heavy-reasoning implementation for complex tasks. |
| `executor-low` | no | core | Fast implementation for simple edits. |
| `planner` | yes | core | Strategic planning workflows. |
| `critic` | yes | quality | Adversarial reviewer -- APPROVE/ITERATE/REJECT verdicts. |
| `verifier` | yes | quality | Evidence-based completion checker. |
| `tracer` | yes | quality | Evidence-driven debugging with competing hypotheses. |
| `code-reviewer` | yes | core | Code review with cited findings. |
| `security-reviewer` | yes | quality | Security-focused code review. |
| `test-writer` | no | quality | Writes narrowly-scoped tests for changed code. |
| `analyst` | yes | core | Deep codebase investigation. |
| `explorer` | no | core | Structured read-only orientation. |
| `api-designer` | no | backend | API schema design (OpenAPI/GraphQL). |
| `db-engineer` | no | backend | Schema design, migrations. |
| `auth-specialist` | no | backend | Auth flows (OAuth, refresh tokens, PKCE). |
| `deploy-engineer` | no | backend | Dockerfiles, CI, deployment configs. |
| `ui-engineer` | no | frontend | Production UI components. |
| `designer` | no | frontend | Design systems, visual composition. |
| `git-master` | no | specialist | Complex git operations, rebases, bisect, reflog recovery. |
| `doc-writer` | no | specialist | Documentation authoring. |
| `migrator` | no | specialist | Framework/language migrations. |
| `scientist` | yes | specialist | Data-driven investigation. |

(See [`catalog-manifest.json`](./catalog-manifest.json) for the full 40-agent list.)

## Skills catalog (highlights)

| Skill | Category | Purpose |
|---|---|---|
| `plan` | planning | Strategic plan file at `plans/YYYY-MM-DD-<slug>-v1.md`. |
| `ralplan` | planning | Consensus planning with architect + critic loop. |
| `autopilot` | execution | Full autonomous idea-to-code. |
| `ralph` | execution | Persistence mode -- does not stop until verified. |
| `turbo` | execution | Maximum parallel throughput. |
| `team` | execution | Multi-agent coordinated execution. |
| `verify` | quality | Evidence-based completion check. |
| `critic` | quality | Adversarial review with verdict. |
| `visual-verdict` | quality | UI visual QA with structured verdict. |
| `ai-slop-cleaner` | quality | Strip AI filler and em-dash spam. |
| `explore` | investigation | Read-only structured orientation. |
| `deep-dive` | investigation | Multi-pass research with citations. |
| `tracer` | debugging | Evidence-driven root cause analysis. |
| `note` | knowledge | Durable notes in `docs/notes/`. |
| `recall` | knowledge | Find prior context from notes/plans/git. |
| `wiki` | knowledge | General external-knowledge Q&A. |
| `remember` | knowledge | Persist rules to `AGENTS.md`. |
| `skillify` | meta | Extract a session pattern into a reusable skill. |
| `doctor` | meta | Diagnose the local install. |
| `release` | release | Cut a clean tagged release with CHANGELOG. |
| `cancel` | control | Safe exit from autonomous loops. |
| `scaffold` | creation | Generate project boilerplate. |
| `docker` | devops | Production Docker configs. |
| `tailwind-v4` | frontend | Tailwind CSS v4 migration and usage. |

## Commands

Commands are file-based slash commands under `commands/*.md`. Each is a short prompt template with `{{parameters}}` for arguments. Invoke from the REPL with `/name <args>`.

```bash
forge
> /scaffold a TypeScript CLI tool using yargs
> /feature add a refresh token flow with rotation
> /bugfix the /health endpoint returns 500 when db is down
> /review src/auth.ts for security issues
> /refactor extract the retry logic in src/http.ts into a shared helper
```

## Configuration

| File | Purpose |
|---|---|
| `.forge.toml` | Forge session, reasoning, update, compact, and retry settings. See [`docs/CONFIGURATION.md`](./docs/CONFIGURATION.md). |
| `.mcp.json.example` | Example MCP server config. Copy to `.mcp.json` and customize. See [`docs/MCP.md`](./docs/MCP.md). |
| `AGENTS.md` | Auto-loaded by forge as user-visible project rules. Includes keyword routing, commit trailer protocol. |

## Template overrides

Forge's built-in Handlebars prompt templates can be overridden by dropping a file with the same name into `~/forge/templates/`. oh-my-forge ships three overrides:

- `forge-doom-loop-reminder.md` -- a stronger loop-breaker that suggests switching to `sage` for re-investigation or re-decomposing the task.
- `forge-pending-todos-reminder.md` -- smarter todo reminder that references the active plan file.
- `forge-partial-skill-instructions.md` -- richer skill catalog injection with clearer triggering guidance.

The `scripts/install.sh --with-templates` flag installs them. Users who customize can preserve their edits through updates via marker-bounded sections (see [`scripts/omf-update.sh`](./scripts/omf-update.sh)).

## Commit trailer protocol

oh-my-forge agents append structured git trailers to commits to document decisions and constraints. See [`AGENTS.md`](./AGENTS.md#commit-trailer-protocol) for the full spec. Example:

```
feat(auth): add refresh token rotation

Constraint: must stay backward-compatible with v1 clients
Rejected: sliding sessions | lost refresh-token revocation control
Confidence: high
Scope-risk: medium
Tested: unit (auth.test.ts), integration (auth.e2e.test.ts)
Co-Authored-By: ForgeCode <noreply@forgecode.dev>
```

## Keyword routing

`AGENTS.md` includes a keyword-routing table read by forge at every turn. Example triggers:

| Say this | Invokes | Behavior |
|---|---|---|
| "don't stop", "keep going", "must complete" | `ralph` skill | Persistence mode |
| "build me", "handle it all", "autopilot" | `autopilot` skill | Full autonomous run |
| "plan", "strategy", "design", "scope" | `plan` skill | Strategic plan file |
| "debug", "root cause", "why is this broken" | `tracer` skill | Evidence-based debugging |
| "review", "critique", "poke holes" | `critic` agent | Adversarial review |
| "verify", "is this done", "prove it works" | `verify` skill | Evidence-based check |
| "walk me through", "explore", "what does this do" | `explore` skill | Structured orientation |
| "simplify", "clean this up" | `code-simplifier` agent | Refactor for readability |

Full table in [`docs/FORGE_KEYWORDS.md`](./docs/FORGE_KEYWORDS.md).

## Doctor + uninstall

```bash
# Diagnose
scripts/doctor.sh --user      # validate ~/forge/
scripts/doctor.sh --project . # validate a project's .forge/
scripts/doctor.sh --repo      # validate the oh-my-forge source tree

# Clean up
scripts/uninstall.sh --user --dry-run   # show what would be removed
scripts/uninstall.sh --user             # actually remove
```

## Migrating from v1

If you used a previous oh-my-forge that shipped `forge.yaml`, run:

```bash
scripts/migrate-from-v1.sh ~/forge
```

This converts `forge.yaml` -> `.forge.toml`, relocates agents to the flat layout, and backs up everything it touches.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `forge list agent` shows only 3 built-ins | Run `scripts/doctor.sh --user` to see what's wrong. Likely cause: agents nested in subdirectories. |
| Skill not loading | Check `skills/<name>/SKILL.md` has only `name` and `description` in frontmatter. Extras are rejected. |
| `.forge.toml` parse error | `python3 -c "import tomllib; tomllib.load(open('~/forge/.forge.toml','rb'))"` to see the line. |
| `.mcp.json` parse error | Strict JSON -- no comments, no trailing commas. Use `jq` to validate. |
| Old tool names (`edit`, `bash`) in agent | See [`docs/REFERENCE.md`](./docs/REFERENCE.md#tools) for the canonical tool catalog. |

## Relationship to other oh-my-* projects

oh-my-forge is the ForgeCode sibling of:

- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) -- the original content pack for Claude Code.
- [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) -- the Codex sibling.
- [oh-my-gemini-cli](https://github.com/Yeachan-Heo/oh-my-gemini-cli) -- the Gemini CLI sibling.

Each adapts the same philosophical approach (multi-agent orchestration, skill-based routing, evidence-driven verification) to the target tool's unique configuration model. oh-my-forge is the **forgecode-native** expression of that philosophy -- no launcher wrappers, no faux tiers, schemas verified against the forgecode source.

## Contributing

See [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md).

## License

MIT. See [`LICENSE`](./LICENSE).

## Credits

- [Yeachan-Heo](https://github.com/Yeachan-Heo) for the original oh-my-claudecode/codex/gemini-cli.
- [ForgeCode](https://forgecode.dev/) team for `forge`.
