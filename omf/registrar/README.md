# omf-registrar — offline safetensors model registrar

Reads `.safetensors` **headers only** (the 8-byte length + JSON header, never the
weight buffer) and emits model footprint rows for the omf manifest. No torch, no
GPU, no model load — pure stdlib. It is an **author-time** tool, **not** an omf
runtime dependency: you run it to (re)generate model rows, then fold them into
`omf.toml`.

## Usage

```bash
# from omf/registrar/
uv run omf-registrar scan PATH [PATH ...] [--format json|toml]
```

`PATH` is either a single `.safetensors` file or a directory holding a sharded
set (`model-00001-of-0000N.safetensors`, summed into one model).

```bash
uv run omf-registrar scan ~/models/Qwen2.5-Coder-14B            # sharded dir → 1 row
uv run omf-registrar scan model.safetensors --format toml      # [[model]] rows
```

Each row carries: `name`, `format`, `path`, `shards`, `tensors`, `params`,
`weight_bytes`, `weight_gib`, `dtypes`. `weight_bytes` is the exact on-disk
tensor total (from `data_offsets`); `params` is the exact element count (from
shapes). Partial scans still emit good rows; exit is non-zero only when *every*
path failed.

## Develop / test

```bash
uv sync
uv run pytest -q
```

Tests synthesize valid safetensors files byte-by-byte, so they run fully offline
with no model downloads.
