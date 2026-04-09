---
name: remember
description: Persist a new rule or preference to AGENTS.md so it survives every future session.
---

Remember this rule: {{parameters}}

Load the `remember` skill and follow its workflow.

Append (or update) the rule in the project's `AGENTS.md` under an appropriate section. If the rule is global (applies across projects), persist it to `~/forge/AGENTS.md` instead and mention the choice.

Show the user the exact diff before writing.

Rule should be:

- **Imperative** ("Always do X", "Never do Y", "Prefer Z over W")
- **Specific** -- no vague guidance
- **Testable** -- you should be able to verify compliance after the fact
