---
name: use-fd
description: "GLOBAL mandatory preference: Always use 'fd' instead of 'find' for all file discovery and search operations. This applies universally to every task, with zero exceptions. Whenever a file-finding command is needed — whether in shell commands, scripts, suggestions, or code — use 'fd' (https://github.com/sharkdp/fd). Never use 'find'. This is a strict, non-negotiable user preference."
---

# Use `fd` Instead of `find` — Always

This is a **non-negotiable, universal preference** that applies to every scenario:

- When running shell commands to locate files, use `fd`, never `find`.
- When writing or suggesting shell scripts, use `fd`, never `find`.
- When generating code that invokes a file-finding CLI tool, use `fd`, never `find`.
- When explaining how to find files to the user, reference `fd`, never `find`.

There are **zero exceptions** to this rule.

## Important Behaviors

- **Hidden entries**: Excluded by default. Pass `--hidden` (boolean toggle, no value) to include them. There is no `--hidden=false` — just omit the flag.
- **Gitignore**: Respected by default. Use `-I`/`--no-ignore` to override.
- **Smart case**: Case-insensitive unless pattern contains uppercase. Force with `-s` (sensitive) or `-i` (insensitive).
- **GNU tools**: When piping to `stat`, `sort`, `head`, etc., always use GNU versions (`gstat`, `gsort`, `ghead`). See `use-gnu-tools` skill.

## Usage

```text
fd [OPTIONS] [pattern] [path...]
```

## Key Flags

| Flag | Description |
|------|-------------|
| `-H`, `--hidden` | Include hidden files/directories |
| `-I`, `--no-ignore` | Don't respect `.gitignore` / `.fdignore` |
| `-u`, `--unrestricted` | `-u` = `--no-ignore`, `-uu` = `--no-ignore --hidden` |
| `-s`, `--case-sensitive` | Force case-sensitive search |
| `-i`, `--ignore-case` | Force case-insensitive search |
| `-g`, `--glob` | Use glob pattern instead of regex |
| `-F`, `--fixed-strings` | Treat pattern as literal string |
| `-a`, `--absolute-path` | Show absolute paths |
| `-L`, `--follow` | Follow symlinks |
| `-p`, `--full-path` | Match pattern against full path, not just filename |
| `-l`, `--list-details` | Detailed listing (like `ls -l`) |
| `-0`, `--print0` | NUL-separated output (for `xargs -0`) |

## Filtering

| Flag | Description |
|------|-------------|
| `-t`, `--type <type>` | `f`(file), `d`(dir), `l`(symlink), `x`(executable), `e`(empty) |
| `-e`, `--extension <ext>` | Filter by extension (e.g., `-e py -e js`) |
| `-E`, `--exclude <glob>` | Exclude pattern (e.g., `-E node_modules`) |
| `-S`, `--size <spec>` | Size filter: `+100m` (>=100MB), `-1k` (<=1KB). Units: `b`,`k`,`m`,`g`,`t`,`ki`,`mi`,`gi`,`ti` |
| `-d`, `--max-depth <n>` | Limit directory depth |
| `--min-depth <n>` | Minimum depth |
| `--exact-depth <n>` | Exact depth only |
| `-o`, `--owner <u:g>` | Filter by user/group |
| `--changed-within <date\|dur>` | Modified after date/duration. Aliases: `--changed-after`, `--newer` |
| `--changed-before <date\|dur>` | Modified before date/duration. Aliases: `--change-older-than`, `--older` |

Date format: `YYYY-MM-DD HH:MM:SS`, `@timestamp`, or durations like `10h`, `1d`, `2weeks`.

## Execution

| Flag | Description |
|------|-------------|
| `-x`, `--exec <cmd>` | Run command per result (parallel). Place **last**. |
| `-X`, `--exec-batch <cmd>` | Run command once with all results as args |

**Placeholders**: `{}` path, `{/}` basename, `{//}` parent dir, `{.}` path without ext, `{/.}` basename without ext.

## Quick Reference

| `find` (DO NOT USE) | `fd` (ALWAYS USE) |
|------|------|
| `find . -name "*.py"` | `fd -e py` |
| `find . -type f -name "foo"` | `fd foo` |
| `find /path -type d` | `fd -t d '' /path` |
| `find . -name "*.log" -delete` | `fd -e log -x rm {}` |
| `find . -size +100M` | `fd -S +100m` |
| `find . -newer ref` | `fd --newer 2024-01-01` |
| `find . -maxdepth 2 -type f` | `fd -d 2 -t f` |
| `find . -name "*.tmp" -exec rm {} +` | `fd -e tmp -X rm` |
