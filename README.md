# oh-my-forge

> ⚠️ **Amateur Export** — This is an unofficial amateur export of [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) for ForgeCode. Expect imperfections. Contributions welcome!

**Multi-agent orchestration for ForgeCode. Zero learning curve.**

*Don't learn ForgeCode. Just use OMF.*

[Get Started](#quick-start) • [Documentation](docs/) • [Agents](docs/AGENTS.md) • [Skills](skills/) • [Configuration](#configuration)

---

## Why oh-my-forge?

ForgeCode is the #1 terminal-native AI coding agent. But out of the box, you're on your own to configure agents, workflows, and conventions. **oh-my-forge** fixes that.

- **30+ specialized agents** — architect, designer, executor, reviewer, debugger, and more
- **Tiered agents** — fast, standard, complex for cost optimization
- **9 execution modes** — Autopilot, Turbo, Eco, Plan, Review, Ralph, Ultrawork, Team, Trace
- **9 skills** — reusable workflow patterns for common tasks
- **Model-agnostic** — works with any provider ForgeCode supports (300+ models)
- **Stack-agnostic** — works for any stack, with optional preset packs
- **Zero config** — copy the files, run forge, done

---

## Quick Start

### Option 1: Clone & Copy (recommended)

```bash
git clone https://github.com/YOUR_USERNAME/oh-my-forge.git
cd oh-my-forge
./scripts/install.sh /path/to/your/project
```

### Option 2: Manual Setup

```bash
# Copy agents to your project or global config
cp -r agents/ /path/to/your/project/.forge/agents/
# Copy the forge.yaml to your project root
cp forge.yaml /path/to/your/project/forge.yaml
```

### Option 3: Global Install

```bash
# Install globally so every project benefits
./scripts/install-global.sh
```

Then just run `forge` in your project. That's it.

---

## Execution Modes

| Mode | Trigger | Use For |
|------|---------|---------|
| **Autopilot** | `autopilot: <task>` | Full autonomous build from idea to code |
| **Turbo** | `turbo: <task>` | Parallel sub-tasks for large changes |
| **Eco** | `eco: <task>` | Budget-conscious, minimal token usage |
| **Plan** | `plan: <task>` | Deep interview + architecture before coding |
| **Review** | `review: <task>` | Code review with security + perf analysis |
| **Ralph** | `ralph: <task>` | Persistence mode — doesn't stop until verified |
| **Ultrawork** | `ultrawork: <task>` | Maximum parallel throughput |
| **Team** | `team: N:agent <task>` | Multi-agent coordinated execution |
| **Trace** | `trace: <bug>` | Evidence-driven debugging |

Modes are triggered by prefixing your prompt with the keyword. Without a keyword, OMF uses intelligent defaults based on task complexity.

---

## Agents (30+)

Agents are markdown files in `.forge/agents/` with YAML frontmatter + system prompt. OMF ships with tiered variants for optimal cost/performance balance:

### Core
| Agent | ID | Tier | Role |
|-------|-----|------|------|
| Architect | `architect` | standard | System design, tech decisions |
| Architect (Fast) | `architect-low` | fast | Quick structure decisions |
| Executor | `executor` | standard | Standard implementation |
| Executor (Fast) | `executor-low` | fast | Quick changes, boilerplate |
| Executor (Complex) | `executor-high` | complex | Large refactors, architecture |
| Code Reviewer | `code-reviewer` | standard | Comprehensive review |
| Planner | `planner` | standard | Task decomposition, planning |
| Debugger | `debugger` | standard | Bug hunting, root cause |

### Frontend
| Agent | ID | Tier | Role |
|-------|-----|------|------|
| Designer | `designer` | standard | UI/UX implementation |
| Designer (Fast) | `designer-low` | fast | Quick UI changes |
| UI Engineer | `ui-engineer` | — | Components, responsive |
| Style Expert | `style-expert` | — | CSS, design systems |
| UX Analyst | `ux-analyst` | — | User flows |

### Backend
| Agent | ID | Role |
|-------|-----|------|
| API Designer | `api-designer` | REST/GraphQL design |
| DB Engineer | `db-engineer` | Schema, migrations |
| Auth Specialist | `auth-specialist` | Auth, security |

### Quality
| Agent | ID | Tier | Role |
|-------|-----|------|------|
| Test Engineer | `test-engineer` | standard | TDD, QA strategy |
| Security Reviewer | `security-reviewer` | standard | Vulnerability scanning |
| Perf Optimizer | `perf-optimizer` | — | Performance analysis |

### Specialist
| Agent | ID | Role |
|-------|-----|------|
| Scientist | `scientist` | Data analysis, ML |
| Doc Writer | `doc-writer` | README, API docs |
| Refactorer | `refactorer` | Code cleanup |
| Migrator | `migrator` | Version upgrades |
| Data Modeler | `data-modeler` | ERD design |
| SEO Expert | `seo-expert` | Technical SEO |
| i18n Expert | `i18n-expert` | Internationalization |
| Git Strategist | `git-strategist` | Git workflow |
| Dep Auditor | `dep-auditor` | Dependencies |

[Full agent documentation →](docs/AGENTS.md)

---

## Skills (9)

Skills are reusable workflow patterns. Use them with the skill command:

| Skill | Description |
|-------|-------------|
| `autopilot` | Full autonomous execution from idea to code |
| `ralph` | Persistence mode — doesn't stop until verified |
| `ultrawork` | Maximum parallel throughput |
| `deep-interview` | Socratic requirements clarification |
| `team` | Multi-agent coordinated execution |
| `trace` | Evidence-driven debugging |
| `learner` | Extract reusable patterns |
| `ultraqa` | Autonomous QA cycling |
| `scaffold` | Generate project boilerplate |

[Full skills documentation →](skills/)

---

## Configuration

### forge.yaml

OMF provides an opinionated `forge.yaml` that you can customize:

```yaml
# oh-my-forge default configuration
max_requests_per_turn: 80
max_tool_failure_per_turn: 5
temperature: 0.4
max_tokens: 16384
max_walker_depth: 3

custom_rules: |
  ## oh-my-forge Rules
  
  ### Execution Mode Detection
  - If the user starts with "autopilot:", enter full autonomous mode
  - If the user starts with "turbo:", decompose into parallel sub-tasks
  - If the user starts with "eco:", minimize token usage, be concise
  - If the user starts with "plan:", interview first, then plan, don't code yet
  - If the user starts with "review:", analyze existing code, don't modify
  
  ### Agent Routing
  - For architecture decisions → use @architect persona
  - For implementation → use @executor persona  
  - For code review → use @reviewer persona
  - For debugging → use @debugger persona
  - For testing → use @test-writer persona
  
  ### Quality Standards
  - Always explain WHY before WHAT
  - Show file paths before code blocks
  - Run linters/tests after changes when possible
  - Prefer small, focused commits over large changes
  - Ask clarifying questions for ambiguous requirements

commands:
  - name: "scaffold"
    description: "Generate project boilerplate"
    prompt: "Analyze the project description and generate a complete boilerplate structure with files, configs, and dependencies."
  - name: "feature"
    description: "Plan and implement a feature end-to-end"
    prompt: "First plan the feature architecture, then implement it step by step with tests."
  - name: "bugfix"
    description: "Analyze and fix a bug"
    prompt: "Analyze the error, trace the root cause, implement a fix, and write a regression test."
  - name: "review"
    description: "Comprehensive code review"
    prompt: "Review the recent changes for bugs, security issues, performance problems, and code quality. Provide actionable feedback."
```

### Environment Variables

```bash
# Optional: set default execution mode
export OMF_DEFAULT_MODE=autopilot

# Optional: enable cost tracking
export OMF_TRACK_COST=true
```

---

## Project Structure

```
oh-my-forge/
├── README.md
├── LICENSE
├── forge.yaml              # Default ForgeCode configuration
├── agents/                 # Agent definitions (markdown + YAML frontmatter)
│   ├── core/
│   │   ├── architect.md
│   │   ├── architect-low.md
│   │   ├── executor.md
│   │   ├── executor-low.md
│   │   ├── executor-high.md
│   │   ├── code-reviewer.md
│   │   ├── planner.md
│   │   └── debugger.md
│   ├── frontend/
│   │   ├── designer.md
│   │   ├── designer-low.md
│   │   ├── ui-engineer.md
│   │   ├── style-expert.md
│   │   └── ux-analyst.md
│   ├── backend/
│   │   ├── api-designer.md
│   │   ├── db-engineer.md
│   │   └── auth-specialist.md
│   ├── devops/
│   │   ├── deploy-engineer.md
│   │   └── infra-planner.md
│   ├── quality/
│   │   ├── test-engineer.md
│   │   ├── test-writer.md
│   │   ├── security-reviewer.md
│   │   └── perf-optimizer.md
│   └── specialist/
│       ├── scientist.md
│       ├── doc-writer.md
│       ├── refactorer.md
│       ├── migrator.md
│       ├── data-modeler.md
│       ├── seo-expert.md
│       ├── i18n-expert.md
│       ├── git-strategist.md
│       └── dep-auditor.md
├── skills/                 # Reusable workflow skills
│   ├── autopilot/
│   ├── ralph/
│   ├── ultrawork/
│   ├── deep-interview/
│   ├── team/
│   ├── trace/
│   ├── learner/
│   ├── ultraqa/
│   └── scaffold/
├── scripts/                # Install & setup scripts
│   ├── install.sh
│   └── install-global.sh
├── examples/               # Example configs per stack
│   └── laravel-vue/
└── docs/
    ├── AGENTS.md
    └── CONTRIBUTING.md
```

---

## Stack Presets (Optional)

OMF is stack-agnostic by default, but ships optional presets in `examples/`:

```bash
# Apply a stack preset on top of base config
./scripts/install.sh /my/project --preset laravel-vue
```

Available presets: `laravel-vue`, `nextjs`, `django`, `rails`, `express-react`, `fastapi-svelte`

---

## Comparison with oh-my-claudecode

| Feature | oh-my-claudecode | oh-my-forge |
|---------|-----------------|-------------|
| Target tool | Claude Code | ForgeCode |
| Model support | Anthropic only | 300+ models (any provider) |
| Installation | Plugin marketplace | Copy files / script |
| Agents | 29 | 32+ |
| Agent tiers | fast/standard/complex | fast/standard/complex (model-agnostic) |
| Skills | 32 | 9 (core) |
| Execution modes | 8 | 9 |
| Cost optimization | Model routing | Tiered agents + eco mode |
| License | MIT | MIT |
| Stack presets | No | Yes (optional) |
| Hooks system | Yes (Claude Code hooks) | Planned (ForgeCode native) |

---

## Contributing

PRs welcome! See [CONTRIBUTING.md](docs/CONTRIBUTING.md).

Priority areas:
- New agent definitions
- Additional skills
- Stack-specific presets
- Documentation

---

## License

MIT

---

**Inspired by:** [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) • [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) • [awesome-forge-agents](https://github.com/antinomyhq/awesome-forge-agents)

**Zero learning curve. Any model. Maximum power.**
