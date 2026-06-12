---
name: write-bash
description: "GLOBAL mandatory preference: Modern GNU Bash 5.3+ programming. Applies whenever writing, reviewing, debugging, or refactoring any Bash code. Enforces strict style, safety, and correctness rules. Treats Bash as a programming language, not a scripting language. Covers language features, error handling, architecture, and macOS/Homebrew GNU tooling requirements."
---

# Modern Bash 5.3+ Programming

All Bash code must target GNU Bash 5.3+. Think programming language, not shell scripting. Minimize external dependencies and subshells.

## Non-negotiable Rules

1. GNU Bash 5.3+ only. Guard with `BASH_VERSINFO` check.
2. **Justfile helpers and short TUI scripts**: `set -euo pipefail`. **Complex standalone scripts** with arithmetic that may evaluate to 0 or complex conditional logic: `set -uo pipefail` + explicit per-command checks. See pitfalls below.
3. macOS: GNU tools via Homebrew g-prefix (`gsed`, `gawk`, `ggrep`, `gfind`, `gxargs`). Never BSD.
4. `.bash` extension. `#!/usr/bin/env bash` shebang.
5. No `eval`. No `function` keyword. No `cat file | cmd`.
6. `printf` over `echo`. `[[ ]]` over `[ ]`/`test`. `(( ))` over `let`/`expr`. `$()` over backticks.
7. Parameter expansion over external commands for string ops.
8. Always quote variables: `"$var"` not `$var`.
9. Explicit per-command error checking in complex scripts. Short helpers may rely on `set -e`.
10. Info to stderr, data to stdout. `LC_ALL=C` unless UTF-8 needed.
11. Typed declarations: `declare -A` assoc, `-n` nameref, `-i` int, `-r` const, `-a` array.
12. Functions max 30 lines, max 3 nesting levels, always `local`.
13. `--dry-run` mode for destructive operations.
14. **TUI / interactive scripts**: `trap 'exit 130' INT TERM HUP` for clean Ctrl+C.

## Header Templates

### Justfile helper / TUI script (short, scoped)

```bash
#!/usr/bin/env bash
# script.bash -- one-line description
# Usage: script.bash [args]
set -euo pipefail
trap 'exit 130' INT TERM HUP

(( BASH_VERSINFO[0] >= 5 )) || { printf 'requires Bash 5+\n' >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1
# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
```

### Standalone complex script

```bash
#!/usr/bin/env bash
# shellcheck disable=SC3028,SC3010
if [ -z "${BASH_VERSINFO+set}" ]; then
  echo >&2 'error: this script requires bash'
  exit 1
fi
((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3))) || {
  printf >&2 'error: bash 5.3+ required (found %s)\n' "$BASH_VERSION"
  exit 1
}
set -uo pipefail
IFS=$' \t\n'
export LC_ALL=C
```

## Style

2-space indent. Max 99 cols. Max 1 blank line. No semicolons except `if; then` / `while; do`.
Naming: `lowercase_with_underscores`. Leading `_` for private. `UPPER_CASE` for exported/constants only.
Format: `shfmt -w -i 2 -ci -sr` | Lint: `shellcheck -x`

## Built-in Substitution Table

```text
AVOID                           PREFER
basename "$f"                   ${f##*/}
dirname "$f"                    ${f%/*}
echo "$s" | wc -c               ${#s}
echo "$s" | tr a-z A-Z          ${s^^}
echo "$s" | sed 's/x/y/g'       ${s//x/y}
seq 1 10                        {1..10}
cat file | grep x               grep x < file
cut -d: -f1                     IFS=: read -r f1 _
lines=$(cat file)               mapfile -t lines < file
for f in $(ls *.txt)            for f in *.txt
if echo "$s" | grep -q x        if [[ $s == *x* ]]
which cmd                       command -v cmd
```

## Common Patterns

### TSV parsing from a variable

```bash
while IFS=$'\t' read -r name grp doc params; do
    # ...
done <<< "$tsv_data"
```

### Safe expansion of possibly-empty arrays

```bash
# "${arr[@]}"              -- aborts under set -u when arr is empty
# "${arr[@]+"${arr[@]}"}"  -- safe: expands to nothing when empty
exec just "$recipe" "${extra_args[@]+"${extra_args[@]}"}"
# Display / string context only (never for exec/command args):
printf '%s\n' "${arr[*]:-}"
```

### gum SIGINT-safe prompts

```bash
val=$(gum input --placeholder="..." --prompt="field › " || true)
[[ -z "$val" ]] && exit 0   # user cancelled or entered nothing
```

### Continue outer loop from inside inner while

```bash
while true; do
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue 2   # jump to outer while
    done <<< "$data"
done
```

### BASH_SOURCE self-location

```bash
# Absolute path to the directory containing the current script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Locate repo root (adjust depth as needed):
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

### Sourcing a sibling library with shellcheck provenance

```bash
# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
```

## Banned Constructs

| Banned | Use instead |
|--------|-------------|
| `eval` | namerefs, assoc arrays, `printf -v` |
| `let` | `(( ))` |
| `function` keyword | `name() { }` |
| bare `set -e` (complex scripts) | `set -uo pipefail` + explicit checks |
| `echo` | `printf` |
| `expr` | `$(( ))` |
| `test` / `[ ]` | `[[ ]]` |
| `seq` | `{1..n}` or `for (( ))` |
| `which` | `command -v` |
| backticks | `$( )` |
| `cat file \| cmd` | `cmd < file` |
| `ls` in scripts | globbing or arrays |
| nested `$(cmd $(cmd2))` | intermediate variables |
| BSD sed/awk/grep/find | GNU gsed/gawk/ggrep/gfind |

## Why Not set -e in Complex Scripts

- `((0))` returns exit 1, killing the script. `((count++))` when count=0 is the common victim.
- Behavior in compound commands, functions, command substitutions is inconsistent.
- Failures in `if`/`while`/`&&`/`||` silently ignored.
- `set -uo pipefail` without `-e` is safe. Add `-x` for debug.
- Short helpers where all statements must succeed and no arithmetic-as-statement appears are safe with `set -euo pipefail`.

## Self-check Before Emitting Code

1. Parameter expansion instead of sed/awk/cut?
2. `[[ ]]` regex/glob instead of grep?
3. `mapfile` instead of `$(cat file)`?
4. Bash arithmetic instead of bc/expr?
5. Globbing instead of find/ls?
6. `< file` instead of `cat file |`?
7. `${var//old/new}` instead of external string tools?
8. `trap 'exit 130' INT TERM HUP` if the script is interactive / TUI?
9. `|| true` on `gum`/interactive calls that must survive user cancellation?

## Reference Files

Load on-demand based on the task:

| Reference | Load when |
|-----------|-----------|
| [references/language.md](references/language.md) | Writing code: parameter expansion, arrays, namerefs, typed declarations, conditionals, loops, builtins, file descriptors, coprocesses, process substitution |
| [references/patterns.md](references/patterns.md) | Implementing features: argument parsing, structured logging, config parsing, JSON/CSV, network, concurrency/locking, retry/backoff, circuit breaker |
| [references/architecture.md](references/architecture.md) | Starting a project: 10-phase skeleton, state tracking, project structure, GNU tools detection, Makefile template |
| [references/safety.md](references/safety.md) | Reviewing code or error handling: security patterns, dry-run, input validation, pitfalls, set -e analysis, exit codes, traps |
| [references/git-batch.md](references/git-batch.md) | Git operations: pre-mutation checklist, safe repo cleaning, branch mutations, commit/push safety, batch processing |
