---
name: ask
description: Consult a second AI CLI from inside a forge session for adversarial review, tie-breaking between approaches, or cross-model synthesis. Supports codex (OpenAI Codex CLI), claude (Claude Code headless), and gemini (Gemini CLI). Checks availability before invoking, captures noteworthy verdicts to notes/, and warns when external calls will be slow. Use when you need a second opinion on a plan, diff, design decision, or security question.
---

# Ask

Get a second opinion from another AI CLI without leaving the current forge session.

## When to invoke

- Adversarial review of a plan or diff before committing to an approach.
- Tie-breaking when two implementation strategies seem equally valid.
- Cross-model synthesis: ask two models the same question and compare.
- Security or correctness gut-check from a model that has not seen the conversation history.
- User says "ask codex", "second opinion", "consult gemini", "what does claude think", or "cross-check this".

## Available advisors

| Advisor | CLI binary | Check availability |
|---|---|---|
| OpenAI Codex CLI | `codex` | `command -v codex` |
| Claude Code headless | `claude` | `command -v claude` |
| Gemini CLI | `gemini` | `command -v gemini` |

Always check availability before invoking. If the requested binary is absent, report it clearly and offer the alternatives that are present.

## Workflow

### Step 1: Check availability

Run via the shell tool:

```bash
for bin in codex claude gemini; do
  if command -v "$bin" > /dev/null 2>&1; then
    printf '%s: available (%s)\n' "$bin" "$(command -v "$bin")"
  else
    printf '%s: NOT FOUND\n' "$bin"
  fi
done
```

Report what is available. If the user requested a specific advisor that is missing, stop and report — do not silently fall back.

### Step 2: Compose the prompt

Construct a self-contained prompt. The external CLI has no session history, so include:

- The exact question or task.
- The relevant code, diff, or plan snippet (inline, not by file reference).
- The specific verdict you need (e.g., "is this safe?", "which approach is better?", "what am I missing?").

Never pipe secrets, tokens, or credentials into the prompt. If the context requires a secret value, replace it with a placeholder and note that in the prompt.

### Step 3: Invoke the advisor

Use the shell tool. These invocations are slow (5–30 seconds is normal); be patient and do not retry prematurely.

**Codex:**

```bash
codex exec "<prompt>"
```

**Claude (headless):**

```bash
claude -p "<prompt>"
```

**Gemini:**

```bash
gemini -p "<prompt>"
```

Capture stdout and stderr. If the command exits non-zero, report the exit code and stderr verbatim.

### Step 4: Present the verdict

Summarize the advisor's response in your own words, then quote the most relevant excerpt verbatim. Structure:

```text
## Advisor Verdict: <advisor-name>

**Question asked**: <one sentence>

**Verdict**: <AGREE | DISAGREE | MIXED | INCONCLUSIVE>

**Key points**:
- ...

**Verbatim excerpt**:
> <most important part of the response>

**My synthesis**: <how this changes or confirms the current approach>
```

### Step 5: Persist noteworthy verdicts

If the verdict is materially useful (changes the approach, surfaces a risk, resolves a tie-break), save it:

```bash
# file naming: YYYY-MM-DD-<topic>.md
# directory: notes/ in the current project root
```

Use the write tool to create `notes/YYYY-MM-DD-<topic>.md` with the full advisor response and your synthesis. Inform the user the note was saved.

Skip saving for trivial, confirmatory, or clearly wrong responses.

## Performance notes

External CLI calls are synchronous and can take 5–30 seconds. If the prompt is large (> ~2 000 tokens of context), warn the user before invoking that it may be slow.

Do not call multiple advisors in parallel unless the user explicitly requests a multi-model comparison — sequential calls are easier to reason about.

## Security rules

- Never include secret values, API keys, tokens, or passwords in the prompt.
- Never pipe the contents of `.env`, `.mcp.json` (env values), or credential files.
- If context requires a redacted value, use `<REDACTED>` as a placeholder.

## Anti-patterns

- Do not construct multi-flag provider invocations beyond the forms shown above — they change across CLI versions.
- Do not parse or reformat the advisor's output before quoting; quote it verbatim.
- Do not claim the advisor said something it did not — quote directly or admit uncertainty.
- Do not retry a failed invocation without diagnosing the error first.
