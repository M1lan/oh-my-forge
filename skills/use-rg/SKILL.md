---
name: use-rg
description: "GLOBAL mandatory preference: Always use 'rg' (ripgrep) instead of 'grep' for all text search operations. This applies universally to every task, with zero exceptions. Whenever a text search command is needed — whether in shell commands, scripts, suggestions, or code — use 'rg' (https://github.com/BurntSushi/ripgrep). Never use 'grep' or '/usr/bin/grep'. This is a strict, non-negotiable user preference."
---

# Use `rg` (ripgrep) Instead of `grep` — Always

This is a **non-negotiable, universal preference** that applies to every scenario:

- When running shell commands to search text, use `rg`, never `grep`.
- When writing or suggesting shell scripts, use `rg`, never `grep`.
- When generating code that invokes a text search CLI tool, use `rg`, never `grep`.
- When explaining how to search text to the user, reference `rg`, never `grep`.

There are **zero exceptions** to this rule. Never use `/usr/bin/grep` or `ggrep` — always use `rg`.

## Important Behaviors

- **Gitignore**: Respected by default. Use `--no-ignore` to override.
- **Hidden files**: Skipped by default. Use `-.`/`--hidden` to include.
- **Binary files**: Skipped by default. Use `-a`/`--text` to search them.
- **Case**: Case-sensitive by default. Use `-i` for insensitive, `-S` for smart case (insensitive unless pattern has uppercase).
- **Regex**: Full regex by default (no `-E` needed). Use `-F` for literal strings.

## Usage

```text
rg [OPTIONS] PATTERN [PATH ...]
rg [OPTIONS] -e PATTERN ... [PATH ...]
command | rg [OPTIONS] PATTERN
```

## Search Flags

| Flag | Description |
|------|-------------|
| `-i`, `--ignore-case` | Case-insensitive search |
| `-s`, `--case-sensitive` | Case-sensitive (default) |
| `-S`, `--smart-case` | Insensitive if pattern is all lowercase |
| `-F`, `--fixed-strings` | Treat pattern as literal, not regex |
| `-w`, `--word-regexp` | Match whole words only (`\b...\b`) |
| `-x`, `--line-regexp` | Match entire lines only (`^...$`) |
| `-v`, `--invert-match` | Print non-matching lines |
| `-m NUM`, `--max-count=NUM` | Limit matches per file |
| `-U`, `--multiline` | Allow matches spanning multiple lines |
| `--multiline-dotall` | Make `.` match `\n` in multiline mode |
| `-P`, `--pcre2` | Use PCRE2 engine (look-around, backrefs) |

## Filter Flags

| Flag | Description |
|------|-------------|
| `-g GLOB`, `--glob=GLOB` | Include/exclude by glob. Prefix `!` to exclude. |
| `-.`, `--hidden` | Search hidden files and directories |
| `--no-ignore` | Don't respect `.gitignore` |
| `-u`, `--unrestricted` | `-u` = `--no-ignore`, `-uu` = + `--hidden`, `-uuu` = + `--binary` |
| `-t TYPE`, `--type=TYPE` | Only search file type (e.g., `-t py`). See `rg --type-list`. |
| `-T TYPE`, `--type-not=TYPE` | Exclude file type |
| `-d NUM`, `--max-depth=NUM` | Limit directory traversal depth |
| `--max-filesize=NUM+SUFFIX` | Skip files larger than size (e.g., `50K`, `80M`) |
| `-L`, `--follow` | Follow symlinks |
| `-z`, `--search-zip` | Search compressed files (gzip, bzip2, xz, lz4, zstd) |
| `-a`, `--text` | Treat binary files as text |

## Output Flags

| Flag | Description |
|------|-------------|
| `-n`, `--line-number` | Show line numbers (default on tty) |
| `-N`, `--no-line-number` | Suppress line numbers |
| `-l`, `--files-with-matches` | Print only filenames with matches |
| `--files-without-match` | Print filenames without matches |
| `-c`, `--count` | Count matching lines per file |
| `--count-matches` | Count total matches per file (not lines) |
| `-o`, `--only-matching` | Print only the matched parts |
| `-A NUM`, `--after-context=NUM` | Show NUM lines after match |
| `-B NUM`, `--before-context=NUM` | Show NUM lines before match |
| `-C NUM`, `--context=NUM` | Show NUM lines before and after |
| `--column` | Show column number of first match |
| `-M NUM`, `--max-columns=NUM` | Truncate lines longer than NUM bytes |
| `--heading` / `--no-heading` | Group matches under filename (tty default) / prefix each line |
| `--vimgrep` | Output `file:line:col:match` (one per match) |
| `--json` | Output as JSON lines |
| `-0`, `--null` | NUL byte after each filename (for `xargs -0`) |
| `--sort=KIND` | Sort by `path`, `modified`, `accessed`, `created` |
| `--sortr=KIND` | Reverse sort |
| `-e PATTERN` | Explicit pattern (allows multiple / leading dashes) |
| `-f FILE` | Read patterns from file |

## Quick Reference

| `grep` (DO NOT USE) | `rg` (ALWAYS USE) |
|------|------|
| `grep -r "pattern" .` | `rg "pattern"` |
| `grep -rn "pattern" dir/` | `rg -n "pattern" dir/` |
| `grep -i "pattern" file` | `rg -i "pattern" file` |
| `grep -l "pattern" *.py` | `rg -l "pattern" -g "*.py"` |
| `grep -v "pattern"` | `rg -v "pattern"` |
| `grep -c "pattern" file` | `rg -c "pattern" file` |
| `grep -E "regex" file` | `rg "regex" file` |
| `grep -w "word" file` | `rg -w "word" file` |
| `grep --include="*.js" -r "pat" .` | `rg "pat" -g "*.js"` |
| `grep --exclude-dir=node_modules -r "pat"` | `rg "pat" -g '!node_modules'` |
| `grep -A 3 -B 3 "pattern"` | `rg -C 3 "pattern"` |
| `grep -rl "pattern" --include="*.py"` | `rg -l "pattern" -t py` |
| `grep -P "look(?=ahead)"` | `rg -P "look(?=ahead)"` |
