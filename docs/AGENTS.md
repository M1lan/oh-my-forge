# oh-my-forge — Agent Reference

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   ForgeCode CLI                   │
├──────────────────────────────────────────────────┤
│               oh-my-forge (OMF)                   │
│  ┌──────────┬──────────┬──────────┬────────────┐ │
│  │  Agents  │ Commands │  Rules   │   Skills    │ │
│  │  (32+)   │  (16+)   │ (routing)│   (9+)     │ │
│  └──────────┴──────────┴──────────┴────────────┘ │
│  ┌──────────────────────────────────────────────┐ │
│  │            Execution Modes                    │ │
│  │ autopilot | turbo | eco | plan | review      │ │
│  │ ralph | ultrawork | team | trace | deep-interview │
│  └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

## Agent Tiers

OMF uses tiered agents for cost optimization:

| Tier | Description | Use For | Examples |
|------|-------------|---------|----------|
| **fast** | Fast, cost-efficient | Simple tasks | Quick fixes, boilerplate, style tweaks |
| **standard** | Balanced | Normal tasks | Feature implementation, reviews, debugging |
| **complex** | Deep reasoning | High-stakes | Architecture decisions, complex refactors |

## Agent Categories

### Core Agents

| ID | File | Tier | Role | Reasoning |
|----|------|------|------|-----------|
| `architect` | `core/architect.md` | standard | System design, tech decisions | ✅ |
| `architect-low` | `core/architect-low.md` | fast | Quick structure decisions | ❌ |
| `executor` | `core/executor.md` | standard | Standard implementation | ❌ |
| `executor-low` | `core/executor-low.md` | fast | Quick changes, boilerplate | ❌ |
| `executor-high` | `core/executor-high.md` | complex | Complex refactors, architecture | ✅ |
| `code-reviewer` | `core/code-reviewer.md` | standard | Comprehensive review | ✅ |
| `planner` | `core/planner.md` | standard | Task decomposition, planning | ✅ |
| `debugger` | `core/debugger.md` | standard | Bug hunting, root cause | ✅ |

### Frontend Agents

| ID | File | Tier | Role |
|----|------|------|------|
| `designer` | `frontend/designer.md` | standard | UI/UX implementation |
| `designer-low` | `frontend/designer-low.md` | fast | Quick UI changes |
| `ui-engineer` | `frontend/ui-engineer.md` | — | Components, responsive |
| `style-expert` | `frontend/style-expert.md` | — | CSS, design systems |
| `ux-analyst` | `frontend/ux-analyst.md` | — | User flows |

### Backend Agents

| ID | File | Tier | Role |
|----|------|------|------|
| `api-designer` | `backend/api-designer.md` | standard | REST/GraphQL design |
| `db-engineer` | `backend/db-engineer.md` | — | Schema, migrations |
| `auth-specialist` | `backend/auth-specialist.md` | — | Auth, security |

### DevOps Agents

| ID | File | Role |
|----|------|------|
| `deploy-engineer` | `devops/deploy-engineer.md` | CI/CD, Docker, deployment |
| `infra-planner` | `devops/infra-planner.md` | Cloud architecture, scaling |

### Quality Agents

| ID | File | Tier | Role |
|----|------|------|------|
| `test-engineer` | `quality/test-engineer.md` | standard | TDD, QA strategy |
| `security-reviewer` | `quality/security-reviewer.md` | standard | Vulnerability scanning |

### Specialist Agents

| ID | File | Role |
|----|------|------|
| `scientist` | `specialist/scientist.md` | Data analysis, ML |
| `doc-writer` | `specialist/doc-writer.md` | README, API docs |
| `refactorer` | `specialist/refactorer.md` | Code cleanup |
| `migrator` | `specialist/migrator.md` | Version upgrades |
| `data-modeler` | `specialist/data-modeler.md` | ERD design |
| `seo-expert` | `specialist/seo-expert.md` | Technical SEO |
| `i18n-expert` | `specialist/i18n-expert.md` | Internationalization |
| `git-strategist` | `specialist/git-strategist.md` | Git workflow |
| `dep-auditor` | `specialist/dep-auditor.md` | Dependencies |

## Agent Selection Guide

| Task Type | Best Agent | Tier |
|----------|------------|------|
| Quick fix | `executor-low` | fast |
| Standard feature | `executor` | standard |
| Complex refactor | `executor-high` | complex |
| Quick architecture | `architect-low` | fast |
| Full architecture | `architect` | standard |
| Simple code check | `executor-low` | fast |
| Full code review | `code-reviewer` | standard |
| Simple UI change | `designer-low` | fast |
| Full UI build | `designer` | standard |
| TDD workflow | `test-engineer` | standard |
| Security audit | `security-reviewer` | standard |
| Data analysis | `scientist` | standard |

## How Agent Routing Works

The `custom_rules` in `forge.yaml` instruct the LLM to adopt the right agent persona based on context:

1. **Explicit**: User references an agent with `@agent-id`
2. **Mode-based**: `plan:` triggers planner, `review:` triggers code-reviewer
3. **Context-inferred**: Keywords like "bug", "test", "deploy" route to the appropriate agent
4. **Multi-agent**: Complex tasks may switch between agents mid-conversation

## Creating Custom Agents

Create a `.md` file in `.forge/agents/` (project) or `~/.forge/agents/` (global):

```markdown
---
id: my-custom-agent
title: "My Custom Agent"
description: "What this agent does"
tier: standard               # Optional: fast, standard, complex
reasoning:
  enabled: true             # Optional: enable extended thinking
tools:
  - read
  - write
  - patch
  - shell
---

Your system prompt goes here as markdown.
Define the agent's expertise, standards, and rules.
```

### Available Tools

| Tool | Description |
|------|-------------|
| `read` | Read files and directories |
| `write` | Create new files |
| `patch` | Modify existing files |
| `shell` | Execute shell commands |

## Agent Precedence

Project-level agents override global agents:

```
./.forge/agents/  (project)  →  ~/.forge/agents/  (global)
```

## Overriding Built-in Agents

To customize ForgeCode's built-in agents, create a file with matching `id`:

```markdown
---
id: "forge"
title: "My Custom Forge"
description: "Forge with my project's conventions"
tier: standard
tools:
  - read
  - write
  - patch
  - shell
---

[Your customized system prompt]
```
