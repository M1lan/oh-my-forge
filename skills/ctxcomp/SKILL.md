---
name: ctxcomp
description: Deterministic, verbatim-validated context compression for LLM input. Shrinks chat logs, specs, source, and memory/rule files 60-80% by removing exact duplicates and low-value filler while PROVING every constraint, decision, and preference survived. Extractive (never generative) so it cannot fabricate. Use before sending large or repetitive context to a model, when compacting a conversation for handoff, when trimming a project-memory/AGENTS.md-style file, or as the pre-send layer under `headroom`. Local, zero-network, exact tiktoken counts.
---

# ctxcomp — validated context compression

Extractive engine. Selects and references existing text, never writes new
text. Every kept token is verbatim from input; a validation verdict proves
nothing critical was dropped. Deterministic: same input + flags = identical
output. Complements RAG/memory — it is the pre-call shrink layer, not a
replacement.

Installed as a `uv` tool (`ctxcomp` on PATH, with `tiktoken` for exact
counts). Source: `~/mysrc/context-compressor/`.

## When to invoke

- About to send a long/repetitive log, spec, or file to a model.
- Compacting a conversation for a fresh-session handoff.
- Trimming a project-memory / rules / AGENTS.md-style file.
- As the deterministic pre-send stage feeding `headroom`.

## When NOT to invoke

- Highly unique prose (little repetition) — payoff is small; the tool is
  dedup-first, not magic.
- You need generative summarization / rewriting — ctxcomp is extractive by
  design (that is the safety property; don't fight it).

## CLI

```bash
ctxcomp conversation.jsonl              # auto-detect mode, print report + write .compressed.md
ctxcomp spec.md --target 0.75           # aim for 75% smaller
ctxcomp app.py --mode code              # force mode (code bytes never altered)
ctxcomp log.jsonl --format json -o out.json
ctxcomp file --format audit             # per-segment keep/drop + reason + score
cat history.jsonl | ctxcomp -           # stdin
ctxcomp --selftest                      # 29 built-in checks (expect ALLPASS)
```

Modes: `conversation` | `document` | `code` | `memory` | `auto`.
Formats: report (default) | `json` | `prompt` | `audit`.

## Library

```python
from ctxcomp import compress, validate
from ctxcomp.formats import to_prompt

result = compress(open("history.jsonl").read(), mode="conversation", target=0.7)
report = validate(result)
assert report.ok                 # verbatim, refs resolve, criticals kept
prompt_ready = to_prompt(result)
print(result.ratio, result.effective_multiplier)
```

## Trust gate — read the verdict

A reduction only counts if `validation ✓ PASS`. The verdict asserts:

- kept text is verbatim (engine cannot generate, so cannot fabricate)
- every dedup reference resolves to a kept segment
- 100% of detected constraints/decisions/preferences retained
- dropped segments carrying factual cues (paths, numbers, code, URLs) are
  FLAGGED for review, never silently discarded

If validation fails or flags matter, raise `--target` (compress less) or
inspect `--format audit` before trusting the output.

## Honest limits

- "Lossless-first", not magically lossless: dedup + whitespace are provably
  lossless; importance-trim and near-dup removal are lossy and always
  labeled as such.
- Compression ratio is input-dependent: repetitive agent logs / multi-
  section docs hit 78-88%; unique prose far less.
- `tiktoken` upgrades counts from heuristic to exact; without it the engine
  still runs on a length heuristic.
