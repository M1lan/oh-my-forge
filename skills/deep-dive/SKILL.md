---
name: deep-dive
description: Extended multi-pass research into a specific topic, feature, or question. Goes beyond surface exploration to build a comprehensive understanding -- multiple sources, multiple angles, cross-referenced evidence, synthesized conclusion. Use when a shallow answer is not enough, when the topic is important, or when the user explicitly asks for depth.
---

# Deep Dive

Extended research. Multiple passes. Cross-referenced evidence. Synthesized conclusion.

## When to invoke

- User says "deep dive", "research this thoroughly", "I want to understand this completely".
- A decision with long-term consequences depends on the answer (architecture, dependency choice, migration path).
- An initial `explore` or `recall` pass surfaced a topic that needs more depth.
- The question is "why does this work this way" on a non-trivial subsystem.

## Workflow

1. **Define the question precisely.** Write it down. If you cannot state the question in one sentence, it is too broad -- narrow it.
2. **Pass 1 -- breadth.** Skim all relevant sources to build a map. Use `sem_search` for concepts, `fs_search` for exact strings, `fetch` for external docs. Do NOT try to understand each source deeply yet.
3. **Pass 2 -- depth.** Pick the 3-5 most relevant sources and read them end-to-end. Take notes. Note contradictions.
4. **Pass 3 -- cross-reference.** For every claim that matters, find at least one independent source that confirms or contradicts it. Git history, tests, and official docs are stronger evidence than comments.
5. **Pass 4 -- synthesize.** Answer the question. Cite every claim. Surface contradictions explicitly. Call out anything you are still unsure about.

## Sources to consider

In order of reliability for codebase questions:
1. The code itself (path:line)
2. Tests (they encode actual behavior)
3. Git history / blame
4. Official external docs for libraries involved
5. Committed docs / ADRs in the repo
6. Comments in the code
7. External blog posts / stackoverflow (only as hints, always verify against the code)

## Rules

- Every factual claim MUST cite its source.
- If two sources disagree, surface it -- do not silently pick one.
- If you cannot find evidence, say "not verified" -- never fabricate.
- Time-box the investigation. If after 3 passes the answer is still unclear, report what you know, what you tried, and what remains open.
- Use the `sage` sub-agent for large multi-file investigations.

## Output

```
## Deep Dive: <question>

### TL;DR
One paragraph answer.

### Background
What is the topic, why does it matter, what are the prerequisites.

### The investigation
- Sources consulted: N files, M external docs
- Passes: 1 breadth, 2 depth, 3 cross-reference

### Findings
1. **Finding A**. path:line + cross-reference path:line
2. **Finding B**. path:line + confirming test path:line

### Contradictions / open questions
- path:line says X but path:line implies Y. The code actually does X based on <test/evidence>.
- Still unclear: <item> -- would need <specific additional evidence>

### Synthesis
What is actually true, in plain language, with confidence level.

### Recommendations
If the question was "should we do X?", what does the evidence say?
```
