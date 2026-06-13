"""`omf-registrar` CLI: scan safetensors models -> footprint rows.

Usage:
    omf-registrar scan PATH [PATH ...] [--format json|toml]

Each PATH is either a single `.safetensors` file or a directory holding a
sharded set (`model-00001-of-0000N.safetensors`). Output is a model footprint
row per PATH, ready to fold into omf.toml or feed a manifest generator.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .safetensors import ModelFootprint, SafetensorsError, footprint


def _toml_str(value: str) -> str:
    """Minimal TOML basic-string escaping (enough for paths/names/metadata)."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def _toml_rows(rows: list[ModelFootprint]) -> str:
    out: list[str] = []
    for fp in rows:
        r = fp.as_row()
        out.append("[[model]]")
        out.append(f"name = {_toml_str(str(r['name']))}")
        out.append(f"format = {_toml_str(str(r['format']))}")
        out.append(f"path = {_toml_str(str(r['path']))}")
        out.append(f"shards = {r['shards']}")
        out.append(f"tensors = {r['tensors']}")
        out.append(f"params = {r['params']}")
        out.append(f"weight_bytes = {r['weight_bytes']}")
        out.append(f"weight_gib = {r['weight_gib']}")
        dtypes = ", ".join(_toml_str(d) for d in r["dtypes"])  # type: ignore[union-attr]
        out.append(f"dtypes = [{dtypes}]")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def _scan(args: argparse.Namespace) -> int:
    rows: list[ModelFootprint] = []
    failures = 0
    for raw in args.paths:
        path = Path(raw)
        try:
            rows.append(footprint(path))
        except SafetensorsError as exc:
            print(f"omf-registrar: {exc}", file=sys.stderr)
            failures += 1

    if args.format == "toml":
        sys.stdout.write(_toml_rows(rows))
    else:
        json.dump([fp.as_row() for fp in rows], sys.stdout, indent=2)
        sys.stdout.write("\n")

    # Non-zero only if EVERY path failed; partial scans still emit good rows.
    if rows:
        return 0
    return 1 if failures else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="omf-registrar",
        description="Offline safetensors-header model registrar for omf.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan", help="scan model paths and emit footprint rows")
    scan.add_argument(
        "paths",
        nargs="+",
        metavar="PATH",
        help="a .safetensors file or a directory of shards",
    )
    scan.add_argument(
        "--format",
        choices=("json", "toml"),
        default="json",
        help="output format (default: json)",
    )
    scan.set_defaults(func=_scan)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
