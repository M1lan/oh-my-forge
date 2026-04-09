---
name: critic
description: Run an adversarial critique on a plan, proposal, diff, or approach. Produces a verdict (READY or NEEDS-WORK) with ranked risks.
---

Critique the following: {{parameters}}

Load the `critic` skill and follow its workflow exactly.

Output a critique report with:
1. **Summary** -- one paragraph
2. **Ranked risks** -- each with severity (critical/high/medium/low) and specific evidence
3. **Blind spots** -- what the proposal is missing
4. **Alternative approaches** -- at least 2
5. **Verdict** -- READY | NEEDS-WORK (with specific blockers)

Be ruthless. Be specific. Cite files with `path:line` when discussing code.
