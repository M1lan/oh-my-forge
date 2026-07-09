---
name: monty-playground
description: "GLOBAL preference: use monty (the sandboxed Rust Python interpreter, ~/.cargo/bin/monty from ~/mysrc/monty) instead of CPython for throwaway Python experiments, behaviour checks, algorithm sketches, and ANY LLM-generated snippet. Covers CLI usage, resource limits, mounts, the supported stdlib subset, the CPython fallback protocol, and monty-llm — the local-ollama-model → monty pipeline. Load when running quick Python experiments, sandboxing untrusted code, or combining local models with safe execution."
---

# monty-playground — sandboxed Python experiments (+ local models)

`monty` is a sandboxed Python 3.14-subset interpreter written in Rust
(pydantic/monty, checked out at `~/mysrc/monty`, installed via
`cargo install` to `~/.cargo/bin/monty`). It cannot touch the network,
subprocesses, the environment, or the filesystem (unless explicitly
mounted) — which is exactly why it is PREFERRED for experiments: escapes
and side effects are structurally impossible.

## When to use monty (default for experiments)

- Quick behaviour checks ("what does `{} | {}` do?"), calculations,
  algorithm sketches, regex/json/datetime experiments.
- ANY code a model just generated — local or frontier — that you want to
  run without trusting it.
- REPL exploration: `monty -i`.

## When to fall back to CPython (`python3` / `uv run python`)

- The snippet needs a module outside monty's subset (see below) or hits a
  `ModuleNotFoundError` / unsupported-feature error.
- Real project work, pytest, anything needing pip packages.
- ALWAYS say so when you fall back, and why (RULE 0: surface, don't hide).

## Commands

```bash
monty -c 'print(sorted({3,1,2}))'          # like python -c
monty script.py                            # run a file
monty -i                                   # REPL
monty --type-check script.py               # type-check first, then run
```

ALWAYS cap resources on experiment runs (untrusted/generated code
especially):

```bash
monty --max-duration 5 --max-memory 256MB -c '...'
# also: --max-allocations N  --max-recursion-depth N  --gc-interval N
```

Filesystem access ONLY via explicit mounts (virtual paths are always
POSIX-style inside the sandbox):

```bash
monty -m "$PWD::/mnt/data::ro" -c 'print(open("/mnt/data/f.txt").read())'
# modes: ro (default) · rw · overlay (in-memory) · optional ::write_limit_bytes
```

Timing + result are printed to stderr (`398µs ❯ None`) — pipe-safe stdout.

## Supported stdlib subset (fixed; no pip, no sys.path)

Importable: `asyncio` `datetime` `json` `math` `os` (subset) `pathlib`
`re` `sys` `typing`. Built in without import: `namedtuple`, `@dataclass`
decorator. NOT available (common trip-ups): `collections`, `functools`,
`itertools`, `random`, `time`, `io`, `dataclasses`-the-module, `copy`,
`string`, `struct`, `hashlib`. Full divergence catalogue (one file per
feature): `~/mysrc/monty/limitations/`.

## Local-model combo: monty-llm

`monty-llm` (this skill dir, symlinked at `~/.local/bin/monty-llm`) has a
LOCAL ollama model write a Python script for a task, then executes it in
the monty sandbox — generation and execution both stay on this machine:

```bash
monty-llm 'print the first 10 happy numbers'
monty-llm -s 'invert a dict with duplicate values'   # -s: show code first
MONTY_LLM_MODEL=ornith:latest monty-llm -t 10 '...'  # model + time cap
```

Flags: `-m MODEL` (default `$MONTY_LLM_MODEL` or `ornith:latest`) ·
`-t SECS` max-duration (default 5) · `-M MEM` max-memory (default 256MB) ·
`-s` show generated code · `-k` keep the generated file (always written
under `~/tmp/`, path printed on failure either way).

The generation prompt constrains the model to monty's module subset; if
the model ignores that and the run fails on an import, either re-prompt or
fall back to CPython *after reviewing the code* — never blind-run
LLM output under CPython when monty rejected it.

## Rebuilding after upstream changes

```bash
cd ~/mysrc/monty && make install-py && cargo install --path crates/monty-cli --locked
```

The repo also carries a local-only `just` harness (`just`, `just menu`,
`just fzf`, `just doctor`) — see `.git/info/exclude` there.
