# Contributing to oh-my-forge

Thanks for your interest in contributing!

## How to Contribute

### Adding a New Agent

1. Choose the right category: `core/`, `frontend/`, `backend/`, `devops/`, `quality/`, `specialist/`
2. Create a markdown file with YAML frontmatter (see existing agents for format)
3. The `id` must be unique across all agents
4. Include: expertise, standards, output format, rules
5. Test it by copying to `.forge/agents/` in a real project and running forge

### Adding a Stack Preset

1. Create a directory in `examples/<stack-name>/`
2. Add stack-specific agents in `examples/<stack-name>/agents/`
3. Add a `forge.yaml` with stack-specific `custom_rules`
4. Add a `README.md` explaining the preset
5. Test with `./scripts/install.sh /tmp/test-project --preset <stack-name>`

### Adding a Command/Skill

1. Add it to the `commands` section in `forge.yaml`
2. Give it a clear `name`, `description`, and `prompt`
3. The prompt should follow a numbered step protocol

### Improving Existing Agents

- Better system prompts that produce higher quality output
- More specific standards and rules
- Better output format templates

## Pull Request Guidelines

- One agent/feature per PR
- Test your changes with ForgeCode before submitting
- Follow existing formatting conventions
- Update `docs/AGENTS.md` if adding/modifying agents
- Update `README.md` tables if adding new agents/commands

## Code of Conduct

Be kind. Be constructive. We're all here to make ForgeCode better.
