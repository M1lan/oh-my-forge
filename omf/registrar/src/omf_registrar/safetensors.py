"""Offline safetensors header reader + footprint math.

The safetensors on-disk format (https://github.com/huggingface/safetensors):

    [0:8]    u64 little-endian  = N, the JSON header length in bytes
    [8:8+N]  UTF-8 JSON header  = { "<tensor>": {dtype, shape, data_offsets:[b,e]},
                                    ... , "__metadata__": {str: str} (optional) }
    [8+N:]   the raw tensor byte buffer

We only ever read the 8-byte length + the JSON header -- never the weight buffer
-- so this is cheap, offline, and needs no torch/numpy/GPU.
"""

from __future__ import annotations

import json
import math
import struct
from dataclasses import dataclass, field
from pathlib import Path

# Spec sanity cap: a header above this is treated as corrupt/hostile, not read.
_MAX_HEADER_BYTES = 100 * 1024 * 1024


class SafetensorsError(ValueError):
    """Raised when a file is not a parseable safetensors container."""


@dataclass(frozen=True)
class TensorInfo:
    name: str
    dtype: str
    shape: tuple[int, ...]
    nbytes: int  # exact on-disk bytes from data_offsets (e-b)

    @property
    def numel(self) -> int:
        # prod of an empty shape (a scalar) is 1, which math.prod gives us.
        return math.prod(self.shape)


@dataclass
class ModelFootprint:
    """Aggregate footprint for one model (single file or a sharded set)."""

    name: str
    path: Path
    shards: list[Path] = field(default_factory=list)
    tensors: int = 0
    params: int = 0
    weight_bytes: int = 0
    dtypes: dict[str, int] = field(default_factory=dict)  # dtype -> param count
    metadata: dict[str, str] = field(default_factory=dict)

    @property
    def weight_gib(self) -> float:
        return self.weight_bytes / (1024**3)

    def as_row(self) -> dict[str, object]:
        """A JSON/TOML-friendly manifest row."""
        return {
            "name": self.name,
            "format": "safetensors",
            "path": str(self.path),
            "shards": len(self.shards),
            "tensors": self.tensors,
            "params": self.params,
            "weight_bytes": self.weight_bytes,
            "weight_gib": round(self.weight_gib, 3),
            "dtypes": sorted(self.dtypes),
            "metadata": self.metadata,
        }


def read_header(path: Path) -> tuple[list[TensorInfo], dict[str, str]]:
    """Read one .safetensors file's header. Returns (tensors, __metadata__)."""
    with path.open("rb") as fh:
        size_bytes = fh.read(8)
        if len(size_bytes) != 8:
            raise SafetensorsError(f"{path}: truncated (no 8-byte length prefix)")
        (header_len,) = struct.unpack("<Q", size_bytes)
        if header_len == 0:
            raise SafetensorsError(f"{path}: zero-length header")
        if header_len > _MAX_HEADER_BYTES:
            raise SafetensorsError(
                f"{path}: header {header_len} bytes exceeds {_MAX_HEADER_BYTES} cap"
            )
        raw = fh.read(header_len)
        if len(raw) != header_len:
            raise SafetensorsError(f"{path}: header truncated")

    try:
        header = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SafetensorsError(f"{path}: header is not valid JSON: {exc}") from exc
    if not isinstance(header, dict):
        raise SafetensorsError(f"{path}: header is not a JSON object")

    metadata = header.pop("__metadata__", {}) or {}
    if not isinstance(metadata, dict):
        raise SafetensorsError(f"{path}: __metadata__ is not an object")

    tensors: list[TensorInfo] = []
    for name, spec in header.items():
        if not isinstance(spec, dict):
            raise SafetensorsError(f"{path}: tensor {name!r} spec is not an object")
        try:
            dtype = str(spec["dtype"])
            shape = tuple(int(d) for d in spec["shape"])
            begin, end = (int(v) for v in spec["data_offsets"])
        except (KeyError, TypeError, ValueError) as exc:
            raise SafetensorsError(f"{path}: tensor {name!r} malformed: {exc}") from exc
        if end < begin:
            raise SafetensorsError(f"{path}: tensor {name!r} has end < begin")
        tensors.append(TensorInfo(name, dtype, shape, end - begin))

    return tensors, {str(k): str(v) for k, v in metadata.items()}


def _shard_files(target: Path) -> tuple[str, list[Path]]:
    """Resolve (model_name, [shard files]) from a file or a directory.

    A directory holding multiple `*.safetensors` is treated as one sharded
    model (the `model-00001-of-0000N.safetensors` convention). A single file
    is its own one-shard model.
    """
    if target.is_file():
        return target.stem, [target]
    if target.is_dir():
        shards = sorted(target.glob("*.safetensors"))
        if not shards:
            raise SafetensorsError(f"{target}: no .safetensors files found")
        return target.name, shards
    raise SafetensorsError(f"{target}: not a file or directory")


def footprint(target: Path) -> ModelFootprint:
    """Compute the footprint of a model at `target` (file or sharded dir)."""
    name, shards = _shard_files(target)
    fp = ModelFootprint(name=name, path=target, shards=shards)
    for shard in shards:
        tensors, meta = read_header(shard)
        for t in tensors:
            fp.tensors += 1
            fp.params += t.numel
            fp.weight_bytes += t.nbytes
            fp.dtypes[t.dtype] = fp.dtypes.get(t.dtype, 0) + t.numel
        # First shard's __metadata__ wins; later shards only fill gaps.
        for k, v in meta.items():
            fp.metadata.setdefault(k, v)
    return fp
