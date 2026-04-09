---
name: explore
description: Guided read-only exploration of a codebase area. Use when orienting to unfamiliar code or answering "where does X live?" / "what does Y do?" style questions.
---

Explore: {{parameters}}

Load the `explore` skill and follow its workflow.

Read-only. Do not modify any file. Output a structured exploration report with:

1. **Scope** -- what was explored and what wasn't
2. **Entry points** -- where execution starts for this feature
3. **Key files** -- cited with `path:line` ranges and one-sentence summaries
4. **Data flow** -- how data moves through the relevant modules
5. **Open questions** -- what's still unclear and where to look next
