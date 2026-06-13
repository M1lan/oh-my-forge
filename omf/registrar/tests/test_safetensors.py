"""Tests for the offline safetensors reader + footprint math.

We synthesize valid safetensors files byte-by-byte (no torch) so the tests are
fully offline and deterministic.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

import pytest

from omf_registrar.cli import main
from omf_registrar.safetensors import SafetensorsError, footprint, read_header

# safetensors dtype byte sizes used only to size the synthetic buffers.
_BYTES = {"F32": 4, "F16": 2, "BF16": 2, "I64": 8, "U8": 1}


def _write_safetensors(
    path: Path,
    tensors: dict[str, tuple[str, tuple[int, ...]]],
    metadata: dict[str, str] | None = None,
) -> int:
    """Write a minimal valid safetensors file. Returns total weight bytes."""
    header: dict[str, object] = {}
    offset = 0
    for name, (dtype, shape) in tensors.items():
        numel = 1
        for d in shape:
            numel *= d
        nbytes = numel * _BYTES[dtype]
        header[name] = {
            "dtype": dtype,
            "shape": list(shape),
            "data_offsets": [offset, offset + nbytes],
        }
        offset += nbytes
    if metadata is not None:
        header["__metadata__"] = metadata

    blob = json.dumps(header).encode("utf-8")
    with path.open("wb") as fh:
        fh.write(struct.pack("<Q", len(blob)))
        fh.write(blob)
        fh.write(b"\x00" * offset)  # zero-filled weight buffer
    return offset


def test_read_header_basic(tmp_path: Path) -> None:
    f = tmp_path / "tiny.safetensors"
    _write_safetensors(
        f,
        {"a": ("F32", (2, 3)), "b": ("F16", (4,))},
        metadata={"format": "pt"},
    )
    tensors, meta = read_header(f)
    by_name = {t.name: t for t in tensors}
    assert by_name["a"].numel == 6
    assert by_name["a"].nbytes == 6 * 4
    assert by_name["b"].numel == 4
    assert by_name["b"].nbytes == 4 * 2
    assert meta == {"format": "pt"}


def test_footprint_single_file(tmp_path: Path) -> None:
    f = tmp_path / "model.safetensors"
    total = _write_safetensors(f, {"w": ("F32", (10, 10)), "bias": ("F32", (10,))})
    fp = footprint(f)
    assert fp.tensors == 2
    assert fp.params == 100 + 10
    assert fp.weight_bytes == total == (100 + 10) * 4
    assert fp.dtypes == {"F32": 110}
    assert len(fp.shards) == 1
    assert fp.weight_gib == pytest.approx(total / (1024**3))


def test_footprint_sharded_dir(tmp_path: Path) -> None:
    d = tmp_path / "big-model"
    d.mkdir()
    t1 = _write_safetensors(d / "model-00001-of-00002.safetensors", {"x": ("BF16", (8, 8))})
    t2 = _write_safetensors(d / "model-00002-of-00002.safetensors", {"y": ("I64", (4,))})
    fp = footprint(d)
    assert fp.name == "big-model"
    assert len(fp.shards) == 2
    assert fp.tensors == 2
    assert fp.params == 64 + 4
    assert fp.weight_bytes == t1 + t2
    assert fp.dtypes == {"BF16": 64, "I64": 4}


def test_scalar_shape_counts_one(tmp_path: Path) -> None:
    f = tmp_path / "scalar.safetensors"
    _write_safetensors(f, {"s": ("U8", ())})
    fp = footprint(f)
    assert fp.params == 1
    assert fp.weight_bytes == 1


def test_truncated_length_prefix(tmp_path: Path) -> None:
    f = tmp_path / "bad.safetensors"
    f.write_bytes(b"\x01\x02\x03")
    with pytest.raises(SafetensorsError, match="truncated"):
        read_header(f)


def test_non_json_header(tmp_path: Path) -> None:
    f = tmp_path / "bad.safetensors"
    blob = b"not json at all"
    f.write_bytes(struct.pack("<Q", len(blob)) + blob)
    with pytest.raises(SafetensorsError, match="not valid JSON"):
        read_header(f)


def test_empty_dir_errors(tmp_path: Path) -> None:
    d = tmp_path / "empty"
    d.mkdir()
    with pytest.raises(SafetensorsError, match="no .safetensors"):
        footprint(d)


def test_cli_json_and_toml(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    f = tmp_path / "m.safetensors"
    _write_safetensors(f, {"w": ("F32", (4, 4))})

    assert main(["scan", str(f)]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["params"] == 16
    assert payload[0]["format"] == "safetensors"
    assert payload[0]["dtypes"] == ["F32"]

    assert main(["scan", str(f), "--format", "toml"]) == 0
    toml_out = capsys.readouterr().out
    assert "[[model]]" in toml_out
    assert "params = 16" in toml_out


def test_cli_all_paths_fail_returns_1(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    missing = tmp_path / "nope.safetensors"
    assert main(["scan", str(missing)]) == 1
    err = capsys.readouterr().err
    assert "omf-registrar:" in err
