---
name: security-review
description: Run an OWASP Top 10 plus secrets and trust-boundary security audit on a diff, module, or set of files. Delegates to the security-reviewer agent, applies zero-noise filtering, and produces severity-and-confidence-rated findings with file:line citations. Never prints secret values. Ends with a BLOCK / WATCH / CLEAR verdict.
---

Security review target: {{parameters}}

Load the `security-review` skill and follow its workflow exactly.

Determine the review scope from the parameters (working tree diff, branch diff, specific module, or file list), identify the attack surface and trust boundaries, delegate to the security-reviewer agent, apply the zero-noise filter, and produce a Security Review report.

Never print secret values in any part of the output. End with a BLOCK / WATCH / CLEAR verdict.
