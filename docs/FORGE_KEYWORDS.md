# Forge Keyword Routing Cheat Sheet

Single-page reference for every natural-language trigger that routes to an oh-my-forge skill, agent, or command.

This file is loaded by forge (or read by the user) to pick the right tool for a request. It complements the keyword routing table in [`../AGENTS.md`](../AGENTS.md).

---

## Execution mode triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "autopilot", "build me", "handle it all", "just do it" | `autopilot` skill | Full autonomous run from idea to code |
| "ralph", "don't stop", "keep going", "must complete", "until it works" | `ralph` skill | Persistence mode -- loops until verified |
| "team", "in parallel", "coordinated", "split the work" | `team` skill | Multi-agent parallel execution |
| "turbo", "maximum speed", "no confirmations", "just write it all" | `turbo` skill | Parallel throughput, no interactive prompts |
| "eco", "quick fix", "one-line", "minimal ceremony" | `eco` skill | Lightweight single-file changes |
| "ultrawork", "parallel tasks", "many at once" | `ultrawork` skill | Max parallel throughput across subtasks |
| "ultraqa", "make the tests pass", "test until green" | `ultraqa` skill | Test/fix cycling loop |
| "ultragoal", "multi-goal initiative", "track goals across sessions", "goal ledger" | `ultragoal` skill | Durable multi-session goal tracking |

---

## Planning triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "plan", "strategy", "design", "scope", "roadmap" | `plan` skill | Writes `plans/YYYY-MM-DD-<slug>-v1.md` |
| "ralplan", "consensus plan", "deliberate plan", "make sure this is right" | `ralplan` skill | Planner+architect+critic iterative planning |
| "deep interview", "clarify requirements", "help me think through" | `deep-interview` skill | Socratic requirements gathering |

---

## Quality / review triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "critique", "poke holes", "what could go wrong", "review this plan" | `critic` skill / `critic` agent | Adversarial review with verdict |
| "verify", "is this done", "prove it works", "evidence that it works" | `verify` skill / `verifier` agent | Evidence-based completion check |
| "review this diff", "code review", "review my changes", "before I merge" | `code-review` skill | Severity-rated diff quality gate |
| "security review", "OWASP scan", "check for vulns", "secrets check", "trust boundary" | `security-review` skill | OWASP + secrets + trust-boundary audit |
| "code review", "review this PR", "review this change" | `code-reviewer` agent | Comprehensive code review |
| "security review", "is this secure", "audit this" | `security-reviewer` agent | Security-focused review |
| "tdd", "test first", "red-green", "write the test first", "test-driven" | `tdd` skill | Red-green-refactor with Iron Law |
| "visual review", "does it match the design", "UI looks right" | `visual-verdict` skill | Structured visual QA |
| "clean this up", "strip the fluff", "remove AI slop", "tighten this" | `ai-slop-cleaner` skill | Strip LLM filler and em-dash spam |

---

## Investigation triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "explore", "walk me through", "what does this do", "where is X" | `explore` skill / `explorer` agent | Structured read-only orientation |
| "deep dive", "research this thoroughly", "understand completely" | `deep-dive` skill / `analyst` agent | Multi-pass research with citations |
| "debug", "root cause", "why is this broken", "trace this" | `tracer` skill / `tracer` agent | Evidence-based debugging |
| "debug test", "failing test", "flaky test" | `debugger` agent | Interactive debug session |
| "performance", "why is this slow", "optimize" | `perf-optimizer` agent | Performance analysis |

---

## Knowledge / memory triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "note this", "write this down", "capture this" | `note` skill | Durable note in `docs/notes/` |
| "remember", "from now on", "always", "never" | `remember` skill | Persist rule to `AGENTS.md` |
| "recall", "have we done this before", "what did we decide" | `recall` skill | Search notes/plans/git |
| "wiki", "teach me", "what is X", "how does Y work" | `wiki` skill | External-knowledge Q&A |
| "learn this", "extract pattern" | `learner` skill | Pattern extraction from session |

---

## Meta / workflow triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "make this a skill", "save this workflow" | `skillify` skill | Extract session into a skill |
| "doctor", "check my install", "something is broken" | `doctor` skill / `scripts/doctor.sh` | Diagnose install |
| "release", "cut a release", "tag a release", "ship v1.2.3" | `release` skill | Prepare tagged release |
| "cancel", "stop", "abort", "never mind" | `cancel` skill | Safe exit from autonomous loops |
| "scaffold", "bootstrap", "new project" | `scaffold` skill | Generate project boilerplate |
| "second opinion", "ask codex", "ask gemini", "ask claude", "cross-check this" | `ask` skill | Multi-model consultation |
| "set up mcp", "add mcp server", "configure context7", "wire up emacs mcp" | `mcp-setup` skill | MCP server wiring |
| "deepinit", "init the codebase docs", "generate AGENTS.md", "document this project for agents" | `deepinit` skill | Hierarchical AGENTS.md generation |
| "omf reference", "how does oh-my-forge work", "what skills are available" | `omf-reference` skill | oh-my-forge reference card |
| "emacs", "open in emacs", "emacs diagnostics", "editor integration" | `emacs-integration` skill | Emacs MCP editor integration |
| "bash", "shell script", "write a script" | `write-bash` skill | GNU Bash 5.3+ house style |
| "grepai", "call graph", "who calls", "semantic search in this codebase" | `use-grepai` skill | Semantic code search |
| "typescript types", "tRPC", "advanced generics", "branded types" | `typescript-pro` skill | Advanced TypeScript patterns |

**House preference skills** (always-active, no trigger needed): `use-rg`, `use-fd`, `use-gnu-tools`, `karpathy-guidelines` apply to all shell commands and code work automatically.

---

## Specialist agent triggers

| Say this | Invokes | Behavior |
|---|---|---|
| "API design", "OpenAPI", "GraphQL schema", "REST endpoint" | `api-designer` agent | API design |
| "database", "schema", "migration" | `db-engineer` agent | DB schema and migrations |
| "auth", "OAuth", "refresh token", "login flow" | `auth-specialist` agent | Auth implementation |
| "Dockerfile", "CI", "deploy", "pipeline" | `deploy-engineer` agent | Deployment configs |
| "docker", "container", "compose" | `docker` skill / `deploy-engineer` | Docker configs |
| "tailwind", "CSS v4", "design tokens" | `tailwind-v4` skill / `style-expert` agent | Tailwind v4 work |
| "UI component", "React component" | `ui-engineer` agent | Component implementation |
| "design system", "visual composition" | `designer` agent | Design systems |
| "UX flow", "user journey" | `ux-analyst` agent | UX analysis |
| "i18n", "translation", "locale" | `i18n-expert` agent | Internationalization |
| "SEO", "meta tags", "sitemap" | `seo-expert` agent | SEO |
| "refactor", "simplify", "clean up code" | `refactorer` agent / `code-simplifier` agent | Refactoring |
| "git rebase", "merge conflict", "bisect", "reflog" | `git-master` agent / `git-strategist` agent | Git operations |
| "write tests", "test coverage", "TDD" | `test-writer` agent / `test-engineer` agent | Test writing |
| "QA", "end-to-end test", "before ship" | `qa-tester` agent | Full QA pass |
| "docs", "README", "API reference" | `doc-writer` agent / `document-specialist` agent | Documentation |
| "data analysis", "notebook", "ML" | `scientist` agent | Data-driven investigation |
| "data model", "ERD", "schema design" | `data-modeler` agent | Data modeling |
| "dependencies", "vulnerable package", "outdated" | `dep-auditor` agent | Dependency audit |
| "migrate framework", "upgrade React", "Node 18 to 20" | `migrator` agent | Framework migrations |
| "infrastructure", "cloud architecture" | `infra-planner` agent | Infra planning |

---

## Priority order

If multiple triggers match, use this priority:

1. **Explicit mode prefix** (`autopilot:`, `ralph:`, `turbo:`) -- always wins.
2. **Explicit skill name** ("use the `critic` skill", "run visual-verdict") -- always wins.
3. **Planning triggers** -- route to planning before execution.
4. **Verification triggers** -- route to verification before claiming done.
5. **Specialist agent triggers** -- route to the most specific agent available.
6. **Fallback** -- `forge` built-in agent handles what nothing else matches.

---

## Escape hatches

| Prefix | Meaning |
|---|---|
| `force:` | Skip the ralplan pre-execution gate and execute directly |
| `!` | Same as `force:` |
| `eco:` | Force lightweight mode even if the request looks complex |
| `turbo:` | Force parallel mode even if the default would be interactive |

---

## See also

- [`../AGENTS.md`](../AGENTS.md) -- the full user-facing rules file with keyword routing.
- [`REFERENCE.md`](./REFERENCE.md) -- skills/commands/templates/tools authoritative reference.
- [`AGENTS.md`](./AGENTS.md) -- contributor docs for the agent model.
