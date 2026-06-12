---
name: code-review
description: Run a structured severity-rated code review on a diff, branch, or set of files. Delegates to the code-reviewer agent (and security-reviewer when trust boundaries are touched). Produces Critical/Major/Minor/Nit findings with file:line citations and a merge verdict.
---

Code review target: {{parameters}}

Load the `code-review` skill and follow its workflow exactly.

Determine the review scope from the parameters (working tree diff, branch vs merge base, specific files, or commit range), then run the full review workflow including trust boundary detection, agent delegation, finding verification, and synthesis.

Produce a Code Review Report with severity-rated findings and a final verdict (APPROVE / REQUEST CHANGES / NEEDS DISCUSSION).
