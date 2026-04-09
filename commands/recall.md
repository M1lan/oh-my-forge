---
name: recall
description: Search existing notes, plans, and git history to find prior decisions or work on a topic.
---

Recall prior work on: {{parameters}}

Load the `recall` skill and follow its workflow.

Search the following in order:

1. `docs/notes/` -- durable notes
2. `plans/` -- historical plans
3. `git log --grep` -- commit messages
4. `AGENTS.md` -- persistent rules

Output a brief report: "Here's what I found, ranked by relevance, with citations." If nothing found, say so clearly.
