---
name: llm-data-format
description: "GLOBAL mandatory preference: Evidence-based data-format selection for any text an LLM will READ or GENERATE. Default to Markdown for instructions/context/prose; YAML for nested config the model must reason over; TOON for high-volume uniform tabular data where token cost dominates; NEVER wrap code-generation in JSON; fenced Markdown code blocks with a language tag for code. Never hand-author JSON/XML purely as an LLM intermediate. Format choice swings accuracy up to 48% and tokens 16-60% and does NOT transfer across model vendors. This is a strict, non-negotiable user preference."
---

# LLM Data-Format Selection — Golden Rule

Format choice is not cosmetic. Across published benchmarks it swings LLM
accuracy by up to 48% and token cost by 16-60%. The most token-efficient
format is often the worst-understood one. Pick the format for the task and
the model, not by habit.

There are zero exceptions to the decision matrix below for content you
author for an LLM to read or that you ask an LLM to produce.

## The one-line default

Default to Markdown for everything an LLM reads — instructions, context,
prose, documentation, retrieval corpora. It costs ~16% fewer tokens than
JSON, gives the best accuracy/efficiency balance across tasks, and matches
the Markdown-heavy training distribution of every major model.

## Decision matrix (pick by task, then verify by model)

| Situation | Use | Why |
|-----------|-----|-----|
| Instructions, context, prose, docs, RAG chunks | Markdown | ~16% fewer tokens than JSON; best comprehension balance; native to training data |
| Nested / hierarchical config the model must reason over | YAML | ~62% accuracy on nested data vs JSON ~50%; ~10% token premium over Markdown is worth it |
| Large uniform arrays of objects, token cost dominates | TOON | 30-60% token reduction; but verify comprehension on your task — TOON can lag Markdown/YAML on understanding |
| Tabular lookup where accuracy is paramount, tokens cheap | Markdown key-value records | Highest lookup accuracy (~61%) at ~2.7x the tokens of CSV |
| Code generation (model writes code) | Fenced Markdown code block + language tag | JSON-wrapping code costs up to 26% pass-rate; never do it |
| Extreme token starvation only | CSV / minified JSON (struct-of-arrays) | Most compact; worst comprehension (~44%); repeat headers every ~100 rows |
| Prompting Claude specifically | XML tags (`<example>`, `<context>`, `<document>`) | Claude was explicitly trained on XML-tagged structure |

## Hard rules

- NEVER wrap a code-generation request in JSON. Quote-escaping breaks
  syntax and the wrapper measurably reduces problem-solving capacity
  (Claude-3.5-Sonnet -25.3%, DeepSeek Coder V2 -26.4%). Use fenced
  Markdown code blocks with a language tag.
- NEVER hand-author JSON or XML purely as an intermediate format for an
  LLM to read. Use TOON (spec: `~/mysrc/toon-spec/spec/SPEC.md`, offline
  preferred; else <https://github.com/toon-format/spec/blob/main/SPEC.md>)
  for uniform structured data, or Markdown/YAML otherwise. This does NOT
  override user-requested formats, machine APIs, MCP payloads, schemas,
  fixtures, or tests — those stay in whatever format they require.
- Avoid CSV unless extreme token pressure forces it; its comprehension is
  the worst of all formats.

## Why the matrix works: the training-data hypothesis

LLMs perform best with formats prevalent in their training data, not with
theoretically optimal ones. Markdown dominates because billions of READMEs,
docs, and posts welded its structure to meaning in model weights. This is
also why TOON — designed for token efficiency — wins on tokens yet can
underperform established formats on comprehension today: the models lack
training exposure. Expect that gap to narrow over 2-3 training cycles.

TOON keeps its mandate where it is strongest (uniform/tabular,
high-volume, token-critical). Markdown is the general default. YAML owns
nested config. This refines — it does not retire — the standing "TOON over
hand-authored JSON" rule.

## Format choice is empirical and model-specific

Preferences do NOT transfer across vendors. GPT-3.5 preferred JSON; GPT-4
preferred Markdown — a full reversal inside one product line. Same-series
models share preferences (IoU > 0.7); different providers diverge
(IoU < 0.2). Larger models are more robust but not format-agnostic.

When the cost or accuracy of a format decision is material, test rather
than assume:

1. Sample 100-500 representative examples.
2. Render the same semantic content into 3-4 candidate formats; verify
   round-trip equivalence.
3. Run the target model at `temperature=0`, ≥3 trials per format.
4. Measure accuracy (Pass@1 / exact-match / F1) AND token count.
5. Apply a matched-pairs t-test (p<0.05) between best and worst; report
   95% CIs.
6. Pick the format on the cost/accuracy Pareto frontier for that model.

## Linter and tooling

- Markdown destined for LLM ingestion is scored by the AI-markdown policy
  at `~/.emacs.d/policies/markdown-ai.rego` (M-x
  `markdown-ide-aipolicy-check`). Rule `AI7001` flags `json`/`xml` fenced
  blocks in context files and points at TOON/Markdown/YAML.
- Convert JSON to TOON with `npx @toon-format/cli input.json -o output.toon`.
- `.editorconfig` at `~/forge/.editorconfig` encodes the whitespace/charset
  conventions for `.md`, `.toon`, `.yaml`, `.json`.
