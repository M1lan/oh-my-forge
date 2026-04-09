---
name: wiki
description: Answer a general-knowledge question without touching the codebase. Good for "what is X", "how does protocol Y work", "best practices for Z", "difference between A and B". Uses fetch for external lookups when needed and synthesizes a concise, cited answer. Use when the question is conceptual, not project-specific.
---

# Wiki

External-knowledge Q&A. The codebase is not involved.

## When to invoke

- "What is X?" / "How does Y work?" / "Best practices for Z?" / "What is the difference between A and B?"
- Question is about a general concept, protocol, language feature, library, pattern, or external tool.
- The user explicitly says "wiki", "teach me", "explain".
- NOT for project-specific questions -- use `explore`, `recall`, or `deep-dive` for those.

## Workflow

1. **Clarify the question.** If ambiguous, ask one clarifying question before answering.
2. **Decide: do I know this well?**
   - If yes (confident, well-known topic): answer directly from training.
   - If no (uncertain, recent, or detailed): use `fetch` to pull authoritative sources (official docs, RFCs, language spec, library README).
3. **Synthesize a concise answer.** Favor:
   - Core idea first, details second.
   - Concrete examples over abstract descriptions.
   - A single clear explanation over multiple competing framings.
4. **Cite sources** when external lookup was used.
5. **Flag uncertainty** if the topic is evolving or you are unsure.

## Rules

- Do not pad answers. A 3-paragraph answer is almost always better than a 10-paragraph one.
- No filler ("It is important to note", "In today's world", etc.) -- see the `ai-slop-cleaner` skill.
- Cite external sources when fetched. Do not cite from memory as if it were a source.
- If the question is actually about the user's project (contains phrases like "our code", "the codebase", "this repo"), redirect to `explore` or `recall`.
- If the question has a definitive answer, give it. If it is a matter of taste or context, say so and give the tradeoffs.

## Output format

No rigid template. Aim for:

- One-line direct answer at the top.
- 2-4 short paragraphs of explanation OR a small table / code block if that is clearer.
- Concrete example.
- Citations if external sources were consulted.
- "Related" pointers if useful.

## Anti-patterns

- Turning a 1-sentence question into a 1000-word essay.
- Listing 10 bullet points when 3 would do.
- "On the one hand... on the other hand..." with no conclusion.
- Refusing to give an opinion on topics that have a clear expert consensus.
