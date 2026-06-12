---
name: ask
description: Consult a second AI CLI (codex, claude, or gemini) for a second opinion on a plan, diff, design decision, or security question. Captures noteworthy verdicts to notes/.
---

Ask: {{parameters}}

Load the `ask` skill and follow its workflow exactly.

Determine which advisor is being requested (codex / claude / gemini) from the parameters, or ask if ambiguous. Then:

1. **Check availability** — run `command -v <binary>` for the requested advisor; report clearly if absent.
2. **Compose a self-contained prompt** — include the relevant code, diff, or plan inline; never reference file paths the advisor cannot see; never include secrets.
3. **Invoke the advisor** via the shell tool using the canonical form from the skill (`codex exec`, `claude -p`, or `gemini -p`). Be patient — calls can take 5–30 seconds.
4. **Present the verdict** in the structured format from the skill (advisor name, question, verdict, key points, verbatim excerpt, synthesis).
5. **Save to notes/** if the verdict is materially useful — file named `YYYY-MM-DD-<topic>.md`.
