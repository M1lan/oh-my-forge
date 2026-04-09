---
name: review
description: Comprehensive code review of a diff, file, or PR. Covers correctness, security, performance, maintainability, and tests.
---

Code review: {{parameters}}

Run as the `code-reviewer` agent's workflow. Cover:

1. **Correctness** -- logic errors, edge cases, off-by-ones
2. **Security** -- injection, auth, input validation, secrets
3. **Performance** -- obvious inefficiencies, N+1 patterns, unbounded loops
4. **Maintainability** -- naming, complexity, duplication
5. **Tests** -- coverage of the change, test quality
6. **Style** -- consistency with project conventions

Output a numbered list of issues, each with severity and `path:line` citation. End with an overall verdict (APPROVE / REQUEST-CHANGES / BLOCK).
