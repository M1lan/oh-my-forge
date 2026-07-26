# Emacs + OMF AI-First Grand Design v1

- date: 2026-07-05
- status: pre-planning
- orchestrator: forge (main); sub-orchestrators: TBD per phase
- scope: ~/mysrc/emacs, ~/.emacs.d, ~/scripts/scripts/dev-utils/e.bash, ~/mysrc/oh-my-workbench/oh-my-forge/, ~/.config/

---

## 0. Situation at planning time

| Item | State |
|------|-------|
| emacs binary | `~/.local/bin/emacs` → `~/mysrc/emacs/src/emacs` (symlink, done) |
| emacsclient | `~/.local/bin/emacsclient` → `~/mysrc/emacs/lib-src/emacsclient` (symlink, done) |
| Emacs.app | `~/Applications/Emacs.app` (copied from nextstep/, done) |
| e.bash | `~/scripts/scripts/dev-utils/e.bash` v3.1.0, 2301 lines, symlinked as `~/.local/bin/emacsclient.bash` |
| omf | `~/mysrc/oh-my-workbench/oh-my-forge/` (skeleton present, `schema_version=0`, UNFINISHED per AGENTS.md) |
| ~/assets/books/ | EMPTY — no local AI books available yet |
| dragon icon | NOT FOUND locally — needs acquisition |

---

## 1. Domain map (topics, threads, tech)

### 1.1 Projects (atomic, SemVer-tagged)

| ID | Name | Location | SemVer start | Description |
|----|------|----------|-------------|-------------|
| P1 | `e-v4` | `~/scripts/scripts/dev-utils/e.bash` | 4.0.0 | e.bash v4 — AI-first, TOML config, dragon icon, omf/rtk/monty/copilot integration |
| P2 | `emf-config` | `~/.config/emf/config.toml` | 0.1.0 | TOML config schema for e.bash v4 (replaces env-var config) |
| P3 | `emacs-justfile` | `~/mysrc/emacs/Justfile` | 0.1.0 | Self-improving Justfile for emacs source tree |
| P4 | `emacsd-justfile` | `~/.emacs.d/Justfile` | 0.1.0 | Self-improving Justfile for emacs config tree |
| P5 | `omf-v2` | `~/mysrc/oh-my-workbench/oh-my-forge/` | 2.0.0 | omf rewrite — full forge wrapper, replaces omc/omx need |
| P6 | `agent-cli-registry` | `~/mysrc/oh-my-workbench/oh-my-forge/omf/agent-registry/` | 0.1.0 | Track/health-monitor all LLM CLI tools |
| P7 | `dragon-icon` | `~/assets/icons/dragon/` | 0.1.0 | Dragon icon for Emacs.app (icns generation + application) |
| P8 | `self-improve-loop` | `~/loops/emacs-self-improve/` | 0.1.0 | Self-improving loop harness for Justfiles and configs |

### 1.2 Threads (cortex)

| Thread | Domain | Priority |
|--------|--------|----------|
| T1 | e.bash v4 architecture + TOML config schema | HIGH |
| T2 | Dragon icon acquisition and application | LOW (aesthetic) |
| T3 | omf v2 design — forge wrapper complete | HIGH |
| T4 | Agent CLI tool registry + health monitor | MEDIUM |
| T5 | Self-improving nested Justfile architecture | HIGH |
| T6 | Cascading subagent loop patterns (extraction to ~/loops/) | HIGH |
| T7 | ~/.config/ improvements (mein-bash, agent-bash-env) | MEDIUM |
| T8 | Knowledge base (docling, ~/assets/books/) — populate first | LOW |

### 1.3 Integration layer (all must integrate)

- forge (primary orchestrator CLI)
- omc / omx (Claude Code + Codex — to be REPLACED by omf for daily use)
- rtk (token optimizer — prefix all CLI calls)
- monty (sandboxed Python for experiments — prefer over CPython)
- github copilot CLI + SDK (copilot as secondary LLM)
- ghostty (terminal — target for e.bash workspace hooks)
- rmux (replaces raw tmux calls — see br issue milansantosi-xiz)
- headroom (context compression — MANDATORY in all loops)
- ast-grep, codegraph, gitingest, probe (emacs C source navigation)
- docling (PDF/doc extraction — cascading subagents only)
- br (issue tracker — breadcrumb everything)
- mempalace + cortex (memory layers)

---

## 2. Pre-planning decisions

### 2.1 Orchestration model

- Main orchestrator: forge (me, this session + resumed sessions)
- Co-orchestrators per phase: executor-high agents for complex design; executor-low for boilerplate
- Fan-out pattern: `wt` worktrees for comparison branches; br issues for tracking; cortex threads for continuity
- Cost model: cheap models for mechanical work (TOML boilerplate, icon tasks, br CRUD); expensive models for architecture only

### 2.2 Never-execute rule scope

"Never execute yourself" applies to: implementing P1-P8 source code, creating Justfile content, writing self-improving loops.
Exceptions (already done or trivially safe): symlinks, prompt save, br issue creation, cortex threads, plan file writing.

### 2.3 Self-improvement architecture (design principles, not implementation)

Every atomic harness element MUST:
1. Have a `version` field (SemVer) readable by a script/agent
2. Have a `self-eval` hook — a command that returns a quality score (0-100)
3. Have a `propose-improvement` hook — calls an LLM/tool to suggest a next diff
4. Have a `apply-improvement` hook — applies + tests the suggestion
5. Log every improvement attempt to a structured JSONL audit trail
6. Gate improvement application on a passing test (never silent regression)

Non-LLM self-improvement preferred methods (LLM is the orchestrator layer, not the algorithm):
- Genetic programming via mutation operators on Bash/Justfile AST (use ast-grep for parse)
- Bayesian optimization of config parameters (monty can run scipy-free numpy-free variants)
- Reinforcement signals from `e doctor` / `e selftest` exit codes
- Coverage tracking via `kcov` or `bashcov` on e.bash paths
- Profile-guided optimization: instrument hot paths, prune cold verbs

### 2.4 Context economy (headroom mandate)

- All subagents MUST call `headroom` before any large file read
- emacs C source navigation: use `codegraph` index if present, else `ast-grep` — NEVER load raw .c files
- `probe extract FILE:LINE` for individual function bodies only
- `gitingest` for high-level project map at start of sub-agent sessions
- `docling` only in leaf subagents with no further delegation

---

## 3. Plan phases

### Phase A: Foundation (DONE or trivial)

- [x] Symlink `~/.local/bin/emacs` → `~/mysrc/emacs/src/emacs`
- [x] Symlink `~/.local/bin/emacsclient` → `~/mysrc/emacs/lib-src/emacsclient`
- [x] Install `~/Applications/Emacs.app` from `nextstep/`
- [x] Save prompt verbatim → `~/prompts/2026-07-05-emacs-ai-system-grand-design.md`
- [x] Create this master plan
- [ ] Create br issues for each project/thread (this session)
- [ ] Create cortex threads (this session)
- [ ] Store plan in mempalace (this session)

### Phase B: Architecture design (read-only, planning agents)

Delegate to `analyst` or `architect` agents in worktrees:

- [ ] B1: e.bash v4 design — study v3.1.0, identify extension points, design TOML config schema, design AI integration hooks
  - Agent: `architect`
  - Tools needed: read (e.bash), ast-grep (function analysis), cortex (thread tracking)
  - Output: `plans/2026-07-05-e-v4-architecture-v1.md`
  - Cheap? NO — requires deep reasoning about the 2301-line codebase

- [ ] B2: TOML config schema draft (P2)
  - Agent: `executor-low` (mechanical once B1 done)
  - Tools: write, toml validation
  - Output: `~/.config/emf/config.toml.schema` + example config

- [ ] B3: omf v2 architecture
  - Agent: `architect`
  - Prior work: read existing `plans/2026-04-09-oh-my-forge-aggressive-rewrite-v1.md` + `plans/2026-06-13-omf-control-plane-v1.md`
  - Output: `plans/2026-07-05-omf-v2-architecture-v1.md`

- [ ] B4: Self-improving Justfile architecture (P3, P4, P8)
  - Agent: `architect` + `critic` review
  - Output: `plans/2026-07-05-self-improving-justfile-v1.md`

- [ ] B5: Agent CLI registry design (P6)
  - Agent: `executor` (relatively mechanical)
  - Output: `plans/2026-07-05-agent-cli-registry-v1.md`

### Phase C: Dragon icon (cheap, aesthetic)

- [ ] C1: Source dragon icon — options:
  - Use `sf-symbols` (dragon is in SF Symbols 5+): `sfsymbols --font=SFSymbolsFallback.ttf --name=lizard.fill --output dragon.svg`
  - OR: download CC0/public domain dragon SVG from opengameart.org via hurl
  - Convert SVG → icns using `rsvg-convert` + `iconutil`
  - Agent: `executor-low` with cheap model
  - DEFER: flag for operator confirmation on icon choice before applying

- [ ] C2: Apply dragon icon to `~/Applications/Emacs.app`
  - Tool: `fileicon set ~/Applications/Emacs.app ~/assets/icons/dragon/dragon.icns`
  - OR: `osascript` approach
  - DEFER until C1 complete

- [ ] C3: Wire dragon icon as default in e.bash v4 / TOML config
  - `[icon] default = "dragon"` in config
  - e.bash applies icon on `dev install` / `harness init`

### Phase D: Execution (sub-agents, fan-out)

After B phases complete:

- [ ] D1: Implement e.bash v4 (P1) — executor-high agent
  - Input: B1 design doc
  - Must pass: `e selftest` (all 30+ cases)
  - SemVer: bump from 3.1.0 → 4.0.0 (breaking: new CLI structure, TOML config)

- [ ] D2: Implement TOML config layer (P2) — executor agent
  - Bash TOML parser (use `tq` for reads, write a generator for defaults)
  - Config location: `~/.config/emf/config.toml` (XDG-compliant)

- [ ] D3: Implement emacs-justfile (P3) — executor-low (template-heavy)
  - Load `justfile-house-style` skill first
  - Thin Justfile + `.just/helpers/` pattern
  - Self-eval hook: `just doctor` exit code

- [ ] D4: Implement emacsd-justfile (P4) — executor-low

- [ ] D5: omf v2 implementation — executor-high (large scope)
  - Fan-out: use `wt` for parallel track development
  - Sub-orchestrator assigned

- [ ] D6: Agent CLI registry (P6) — executor agent
  - SQLite + JSONL (reuse br patterns)
  - Health monitor: scheduled via launchd

- [ ] D7: Self-improving loop harness (P8) — executor-high
  - Land in `~/loops/emacs-self-improve/` with SemVer tag

### Phase E: Integration + wiring

- [ ] E1: Wire all pieces via omf verbs
- [ ] E2: Update `~/.config/sh/agent-bash-env.bash` with new loop patterns
- [ ] E3: Update `~/forge/skills/emacs-integration/SKILL.md` (if exists) or create
- [ ] E4: AGENTS.md for `~/mysrc/emacs/` and `~/.emacs.d/`

---

## 4. br issues to create (this session)

| ID | Type | Title | Priority |
|----|------|-------|----------|
| - | epic | e.bash v4 — AI-first complete rewrite | P1 |
| - | task | TOML config schema for emf | P1 |
| - | task | Dragon icon — source + apply + wire | P2 |
| - | epic | omf v2 — complete forge wrapper | P1 |
| - | task | Agent CLI registry + health monitor | P2 |
| - | epic | Self-improving nested Justfile system | P1 |
| - | task | emacs-justfile (P3) | P2 |
| - | task | emacsd-justfile (P4) | P2 |
| - | task | Self-improving loop harness → ~/loops/ | P1 |
| - | task | Populate ~/assets/books/ (docling knowledge base) | P2 |
| - | task | Wire rmux into e.bash v4 workspace hooks | P1 |
| - | task | Integrate rtk into e.bash v4 AI track | P1 |
| - | task | GitHub Copilot CLI/SDK integration layer | P2 |

---

## 5. Cheap vs expensive model routing

| Task | Model tier | Rationale |
|------|-----------|-----------|
| Dragon icon fetch + convert | cheap/free | mechanical wget + convert |
| TOML boilerplate generation | cheap | template instantiation |
| br issue creation | cheap | CRUD |
| Justfile template from spec | cheap | pattern-matching |
| e.bash v4 architecture design | expensive | 2301-line codebase understanding |
| Self-improving loop design | expensive | novel ML/GP architecture |
| omf v2 architecture | expensive | system design |
| Cascading subagent pattern design | expensive | meta-architecture |

---

## 6. Known blockers / deferred items

| Item | Blocker | Action |
|------|---------|--------|
| Dragon icon | Need operator preference for style (SF Symbol lizard? Custom dragon? ASCII dragon?) | DEFER, ping operator |
| ~/assets/books/ | Empty — no books to extract | DEFER: source books or skip |
| omf schema_version=0 | Known UNFINISHED per AGENTS.md | B3 resolves |
| emacsclient binary | lib-src/emacsclient works but not built with --with-mailutils? | Verify with `e doctor` |
| make install | e.bash::_e_dev_install refuses prefix outside ~ | nextstep approach preferred |

---

## 7. Improvement pattern to extract (per §17.4)

Pattern: `cascading-context-budget-subagent`
- Problem: large codebase (emacs C source ~370 files) → context overflow
- Solution: root agent calls `headroom`, decides budget; delegates leaf queries to cheap subagents each with 1 file/function budget; root collects structured summaries
- Loop body: `headroom check → budget assign → delegate → collect → synthesize`
- Termination: all questions answered OR budget exhausted
- Parameters: codebase root, question set, budget per leaf
- Extract to: `~/loops/cascading-context-budget/v0.1.0/`
- Tag: `looping-pattern`, `context-economy`, `emacs-navigation`
