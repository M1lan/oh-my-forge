---
name: learner
description: Extract reusable patterns, recipes, and conventions from a finished session so they can be preserved as a skill, an AGENTS.md rule, or a team playbook. Use after a non-trivial task completes successfully, when the user says "capture what we learned", or when a repeatable pattern emerges that is worth codifying for future work.
---

<Purpose>
Learner extracts reusable patterns from successful debugging or implementation sessions. It creates portable skill files that auto-inject when relevant context is detected.
</Purpose>

<Use_When>
- User says "learner", "extract pattern", "remember this solution"
- You solved a tricky bug that might recur
- You discovered an elegant solution to a common problem
- User wants to build reusable knowledge
</Use_When>

<Do_Not_Use_When>
- The pattern is too specific to be reusable
- The solution might have unintended side effects if blindly reused
- Quick fixes that don't teach anything lasting
</Do_Not_Use_When>

<Pattern_Quality_Gates>
A good pattern to extract:
- Solves a specific, recurring problem
- Is generalizable without losing effectiveness
- Has clear trigger conditions
- Includes the solution and explanation

A BAD pattern to extract:
- Context-specific workarounds
- Hacks that mask symptoms rather than fix root causes
- Solutions tied to specific project state
</Pattern_Quality_Gates>

<Output>
Create a skill file in `.forge/skills/` or `~/.forge/skills/`:

```markdown
---
name: <pattern-name>
description: <one-line description>
triggers: ["keyword1", "keyword2", "keyword3"]
source: extracted
---

## Problem
[What this pattern solves]

## Solution
[How to solve it]

## Example
[Concrete example from the session]
```
</Output>

<Storage_Locations>
| Scope | Path | Use For |
|-------|------|---------|
| Project | `.forge/skills/` | Project-specific patterns |
| Global | `~/.forge/skills/` | Universal patterns |
</Storage_Locations>

<Auto_Ingestion>
Patterns are matched against:
- User prompts
- Error messages
- File content being read

When matched, the pattern is auto-injected into context.
</Auto_Ingestion>

<Examples>
<Good>
User: "learner: extract the fix for aiohttp proxy crashes"
Why good: Specific problem (proxy crash), reusable solution
</Good>

<Good>
Learner: "Extracted: fix-react-useeffect-cleanup - handles async cleanup in useEffect"
Why good: Common React pitfall, generalizable pattern
</Good>

<Bad>
User: "learner: extract the specific workaround for this weird config"
Why bad: Too context-specific to be reusable
</Bad>
</Examples>
