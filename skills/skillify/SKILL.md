---
name: skillify
description: Extract a proven pattern, workflow, or recipe from a session into a new skill. Produces a properly-structured SKILL.md under ~/forge/skills/<name>/ (global) or .forge/skills/<name>/ (project-local). Use when the user says "make this a skill", "I want to reuse this", or when a pattern emerges that is clearly worth capturing for future sessions.
---

# Skillify

Turn a proven workflow into a reusable skill.

## When to invoke

- User says "make this a skill", "I want to reuse this", "save this workflow".
- A non-trivial multi-step pattern has been used successfully and is likely to recur.
- You notice you are re-deriving the same approach across sessions and want to stop.

## Pre-flight checks

Before writing anything:

1. **Is this actually a skill?** Skills encode workflows or reference knowledge, not one-off tasks. If it only applies to one context, capture it as a `note` instead.
2. **Does a similar skill already exist?** Check `~/forge/skills/` and `.forge/skills/`. If yes, suggest updating that skill instead of creating a new one.
3. **What is the trigger?** A skill needs a clear "when to invoke" so future sessions know to reach for it.

## Structure (REQUIRED)

A skill lives at:

- `~/forge/skills/<name>/SKILL.md` -- user-global
- `.forge/skills/<name>/SKILL.md` -- project-local

The SKILL.md file MUST start with YAML frontmatter with exactly these two fields:

```markdown
---
name: <kebab-case-name>
description: <one to three sentences, <=500 chars. Describe what the skill does AND when to invoke it. Third-person, imperative. This text is what future sessions see when deciding whether to load the skill.>
---

# <Skill Title>

<Body sections below.>
```

**Do NOT** add `argument-hint`, `level`, `tier`, `category`, or any other fields. Only `name` and `description`.

## Body sections (recommended)

```markdown
## When to invoke

Bullet list of triggers -- what user phrasing, what conditions.

## Workflow

Numbered steps.

## Rules

Hard constraints. "Never do X", "Always cite path:line".

## Output

What the skill should produce (format, example, what to hand back to the user).
```

Supporting files can live alongside `SKILL.md` in the same directory (e.g. `REFERENCE.md`, `TEMPLATE.md`, `EXAMPLES.md`). They are NOT loaded automatically -- the SKILL.md body should reference them so the invoker knows to read them.

## Workflow

1. **Name the skill.** Kebab case. Short. One word if possible. Avoid generic names like "helper" or "utility".
2. **Write the description.** This is the most important part -- it determines whether the skill gets discovered. Include what it does AND when to use it, in <=500 chars.
3. **Draft the body** with the four canonical sections (When to invoke / Workflow / Rules / Output).
4. **Decide the scope.** User-global (`~/forge/skills/`) or project-local (`.forge/skills/`). Ask if unclear.
5. **Create the directory and SKILL.md.** Do NOT create any supporting files unless the skill genuinely needs them.
6. **Tell the user** the path, the name, and one example of how to invoke it.
7. **Add an entry to the project's catalog-manifest.json if one exists** (category: `user` for custom skills, or the appropriate existing category).

## Validation

After writing, verify:

- YAML frontmatter parses (`python3 -c "import yaml; yaml.safe_load(open('<path>').read().split('---')[1])"`).
- Only `name` and `description` keys present.
- Description is under 500 chars.
- Body has a clear "When to invoke" section.

## Output

```text
Created skill: <name>
Location: <path/to/SKILL.md>
Scope: user-global | project-local
Trigger: invoke when <description of trigger>
```

## Anti-patterns

- Generic skill names (`helper`, `tool`, `stuff`, `util`).
- Descriptions that only say what it does and not when to use it.
- Adding fields beyond `name` and `description` (they will be rejected by the loader).
- Creating a skill for a one-off task.
- Skipping the "When to invoke" section (without it, no future session will find the skill).
- Overloading a single skill with multiple unrelated workflows -- split into multiple skills instead.
