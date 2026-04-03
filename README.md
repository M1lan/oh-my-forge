# oh-my-forge

> ⚠️ **Amateur Export** — This is an unofficial amateur export of [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) for [ForgeCode](https://forgecode.dev/). It was created by an AI and likely contains errors, missing features, and imperfect conversions. Contributions, bug reports, and improvements are welcome!

**Multi-agent orchestration for ForgeCode. Zero learning curve.**

_Don't learn ForgeCode. Just use OMF._

[Get Started](#quick-start) • [Agents](docs/AGENTS.md) • [Skills](skills/) • [Configuration](#configuration) • [Contributing](#contributing)

---

## Why oh-my-forge?

ForgeCode is the terminal-native AI coding agent. But out of the box, you're on your own to configure agents, workflows, and conventions. **oh-my-forge** fixes that.

- **30+ specialized agents** — architect, designer, executor, reviewer, debugger, and more
- **10 execution modes** — Autopilot, Turbo, Eco, Plan, Review, Ralph, Ultrawork, Team, Trace, Deep-Interview
- **12 skills** — reusable workflow patterns for common tasks
- **Design systems** — shadcn/ui, Radix, Base UI documentation included
- **Docker support** — production best practices skill
- **Model-agnostic** — works with any provider ForgeCode supports
- **Stack-agnostic** — works for any stack
- **Zero config** — copy the files, run forge, done

---

## Quick Start

### Option 1: Clone & Copy (recommended)

```bash
git clone https://github.com/your-username/oh-my-forge.git
cd oh-my-forge
./scripts/install.sh /path/to/your/project
```

### Option 2: Global Install

```bash
./scripts/install.sh --global
```

Then just run `forge` in your project.

### Option 3: From Scratch

```bash
# Copy agents to your project
cp -r agents/ ~/.forge/agents/

# Copy skills to your project
cp -r skills/ ~/.forge/skills/

# Copy the forge.yaml
cp forge.yaml ~/.forge/forge.yaml
```

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
| **Deep-Interview** | `deep-interview: <idea>` | Socratic requirements clarification |

---

## Agents (30+)

Agents are markdown files with YAML frontmatter + system prompt.

### Core
| Agent | Role |
|-------|------|
| `architect` | System design, tech decisions |
| `executor` | Standard implementation |
| `code-reviewer` | Comprehensive review |
| `planner` | Task decomposition |
| `debugger` | Bug hunting, root cause |

### Frontend
| Agent | Role |
|-------|------|
| `designer` | UI/UX implementation |
| `ui-engineer` | Components, responsive |
| `style-expert` | CSS, design systems |
| `ux-analyst` | User flows |

### Backend
| Agent | Role |
|-------|------|
| `api-designer` | REST/GraphQL design |
| `db-engineer` | Schema, migrations |
| `auth-specialist` | Auth, security |

### Quality
| Agent | Role |
|-------|------|
| `test-engineer` | TDD, QA strategy |
| `security-reviewer` | Vulnerability scanning |
| `perf-optimizer` | Performance analysis |

### Specialist
| Agent | Role |
|-------|------|
| `scientist` | Data analysis, ML |
| `doc-writer` | README, API docs |
| `refactorer` | Code cleanup |
| `deploy-engineer` | Deployment |
| `dep-auditor` | Dependencies |

[Full agent documentation →](docs/AGENTS.md)

---

## Skills (12)

Skills are reusable workflow patterns.

| Skill | Description |
|-------|-------------|
| `autopilot` | Full autonomous execution |
| `ralph` | Persistence mode — doesn't stop until verified |
| `ultrawork` | Maximum parallel throughput |
| `deep-interview` | Socratic requirements clarification |
| `team` | Multi-agent coordinated execution |
| `trace` | Evidence-driven debugging |
| `learner` | Extract reusable patterns |
| `ultraqa` | Autonomous QA cycling |
| `scaffold` | Generate project boilerplate |
| `tailwind-v4` | Tailwind CSS v4 patterns |
| `docker` | Docker best practices |
| `turbo` | Fast parallel execution |
| `eco` | Lightweight minimal tasks |

---

## Design Systems

Built-in documentation for popular UI libraries:

| System | Description |
|--------|-------------|
| **shadcn/ui** | React + Tailwind + Radix (recommended) |
| **Radix UI** | Headless primitives |
| **Base UI** | Modern headless alternative |

---

## Configuration

### forge.yaml

OMF provides an opinionated `forge.yaml` with rules for execution modes, agent routing, and quality standards.

### Environment Variables

```bash
# Optional: set default execution mode
export OMF_DEFAULT_MODE=autopilot
```

---

## Project Structure

```
oh-my-forge/
├── README.md
├── LICENSE
├── forge.yaml              # Default ForgeCode configuration
├── agents/                 # Agent definitions
│   ├── core/               # Architect, executor, etc.
│   ├── frontend/           # Designer, ui-engineer, etc.
│   ├── backend/            # API designer, db-engineer, etc.
│   ├── devops/             # Deploy, infra
│   ├── quality/            # Test, security, perf
│   └── specialist/         # Scientist, doc-writer, etc.
├── skills/                 # Reusable workflow skills
│   ├── autopilot/
│   ├── ralph/
│   ├── tailwind-v4/
│   ├── docker/
│   └── ...
├── design-system/          # UI library documentation
│   ├── shadcn/
│   ├── radix/
│   └── base-ui/
├── scripts/                # Install scripts
└── docs/                   # Documentation
```

---

## Contributing

> ⚠️ **This is an amateur export.** If you find errors, missing features, or want to improve anything, your contribution is welcome!

### What Needs Help

- **Agent improvements** — Better prompts, missing agents
- **Skill development** — New skills for common workflows
- **Documentation** — Fix errors, add examples
- **Design systems** — Add more UI libraries
- **Bug reports** — Things that don't work as expected
- **Feature requests** — Missing oh-my-claudecode features

### How to Contribute

1. **Fork the repo**
2. **Make your changes** — Fix bugs, add features, improve docs
3. **Test locally** — Use `./scripts/install.sh /your/test/project`
4. **Submit a PR** — Describe what you changed and why

### Reporting Issues

- Missing or incorrect agent prompts
- Skills that don't follow documented behavior
- Missing features from oh-my-claudecode
- Documentation errors
- Build/install issues

### Ideas for Contributions

- [ ] Add missing oh-my-claudecode skills (swarm, ultrapilot, etc.)
- [ ] Improve agent prompts with better instructions
- [ ] Add more design system documentation
- [ ] Create stack-specific presets (Next.js, Laravel, etc.)
- [ ] Add examples directory with sample projects
- [ ] Improve error handling in install scripts
- [ ] Add tests for skills and agents
- [ ] Create a CONTRIBUTING.md with detailed guidelines

---

## Comparison with oh-my-claudecode

| Feature | oh-my-claudecode | oh-my-forge |
|---------|-----------------|-------------|
| Target tool | Claude Code | ForgeCode |
| Model support | Anthropic only | 300+ models |
| Installation | Plugin marketplace | Copy files / script |
| Agents | 29 | 30+ |
| Skills | 32 | 12 (core) |
| Execution modes | 8+ | 10 |
| Team mode | Yes | Simplified |
| Design systems | No | Yes (shadcn, Radix, Base UI) |
| Docker skill | No | Yes |
| Tailwind v4 | No | Yes |
| License | MIT | MIT |

---

## License

MIT

---

**Inspired by:** [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) • [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)

**Zero learning curve. Any model. Maximum power.**
