# Safety, Security, and Common Pitfalls

Error handling, security patterns, anti-patterns, and the set -e deep dive.

## Contents

- [Error handling philosophy](#error-handling-philosophy)
- [Trap patterns](#trap-patterns)
- [Debugging](#debugging)
- [Exit code conventions](#exit-code-conventions)
- [Dry-run pattern](#dry-run-pattern)
- [Secure file operations](#secure-file-operations)
- [Input validation](#input-validation)
- [The set -e deep dive](#the-set--e-deep-dive)
- [Common pitfalls](#common-pitfalls)
- [Anti-patterns catalog](#anti-patterns-catalog)

## Error handling philosophy

Do NOT use `set -e`. Explicitly check return codes where it matters:

``` bash
cd "$target_dir" || { printf 'err. cannot cd to %s\n' "$target_dir" >&2; return 1; }

if ! some_command; then
  printf 'error: some_command failed\n' >&2
  return 1
fi
```

Use meaningful messages and appropriate exit codes. Handle expected failures
gracefully.

## Trap patterns

``` bash
cleanup() {
  local exit_code=$?
  rm -f "$temp_file" "$lock_file"
  exit "$exit_code"
}
trap cleanup EXIT

# signal handling

trap 'exit 130' INT    # ctrl-c
trap 'exit 143' TERM   # termination
trap 'exit 141' PIPE   # broken pipe
```

ERR trap for verbose debugging (pair with `set -E` for function propagation):

``` bash
trap 'rc=$?; printf "ERR at %s:%d: %s (rc=%d)\n" \
  "${BASH_SOURCE[0]}" "$LINENO" "$BASH_COMMAND" "$rc" >&2' ERR
```

DEBUG trap runs before each command. RETURN trap on function return.
Enable inheritance: `set -T` (functrace) or `declare -ft name`.

## Debugging

``` bash
set -uo pipefail     # production
set -xuo pipefail    # debug (trace every command)
```

Enhanced PS4 for trace output:

``` bash
export PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
```

Redirect trace to file:

``` bash
exec {TRACE_FD}>trace.log
BASH_XTRACEFD=$TRACE_FD
set -x
```

Targeted debugging:

``` bash
set -x

# ... suspect code ...

set +x
```

## Exit code conventions

``` bash
declare -ri EXIT_SUCCESS=0
declare -ri EXIT_FAILURE=1
declare -ri EXIT_USAGE=2
declare -ri EXIT_CONFIG=3
declare -ri EXIT_PERMISSION=4
declare -ri EXIT_NETWORK=5
declare -ri EXIT_TIMEOUT=6

exit_with_error() {
  local message=$1 code=${2:-$EXIT_FAILURE}
  printf 'error: %s\n' "$message" >&2
  exit "$code"
}
```

Signal exits: INT=130, TERM=143, PIPE=141.

## Dry-run pattern

``` bash
declare -gi DRY_RUN=0

# wrapper for destructive operations

safe_exec() {
  if (( DRY_RUN )); then
    printf '[DRY-RUN] would run: %s\n' "$*" >&2
  else
    "$@"
  fi
}
```

## Secure file operations

``` bash

# scoped umask for sensitive files

secure_write() {
  local file=$1 content=$2
  local old_umask
  old_umask=$(umask)
  umask 0077
  if (( DRY_RUN )); then
    printf '[DRY-RUN] would write %d bytes to: %s\n' "${#content}" "$file" >&2
  else
    printf '%s' "$content" > "$file"
  fi
  umask "$old_umask"
}
```

- Use `mktemp` for temp files: `temp_file=$(mktemp)`
- Scope `umask 0077` to sensitive ops only, not globally
- Sanitize filenames before use
- Never source untrusted files

## Input validation

- Always quote variables: `"$var"` not `$var`
- NEVER use `eval` (code injection)
- Validate all user input and CLI args
- Use `${var:?error message}` to fail fast on missing values
- Treat paths as data: use arrays for arg building

``` bash
args=(--opt "$val" --file "$path")
cmd "${args[@]}"
```

## The set -e deep dive

### Why we avoid it

`set -e` (errexit) is excluded from our standard header:

1. `((0))` returns exit 1. `((count++))` when count=0 evaluates the
   pre-increment value (0), returns 1, kills the script.

2. Failures in `if`, `while`, `&&`, `||` contexts are silently exempt -- making
   behavior unpredictable.

3. Varies between compound commands, functions, and command substitutions.

4. Masks errors rather than handling them.

### Our position

Use `set -uo pipefail` (no `-e`). Add `-x` for debug.

### When scripts DO use set -e

If inheriting or maintaining code that uses `set -e`:

``` bash
set -Eeuo pipefail
shopt -s inherit_errexit    # make $() respect -e
```

- `-E` (errtrace): ERR trap propagates into functions
- `inherit_errexit`: command substitutions inherit -e
- Know every exception: `if`, `while`, `&&`, `||`, `!`, negation in list

### Alternative robust skeleton (with set -e)

``` bash
#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe
IFS=$' \t\n'

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
cleanup() { :; }
trap cleanup EXIT
trap 'die "at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}"' ERR
```

Valid but requires understanding all `-e` exceptions.
Default `set -uo pipefail` is safer.

## Common pitfalls

### Pipe subshell problem

``` bash

# WRONG: variable set in subshell, lost after pipe

cmd | while read -r line; do
  ((count++))
done

# count is still 0

# RIGHT: process substitution or here-string

while IFS= read -r line; do
  ((count++))
done <<< "$output"

# or with lastpipe:

shopt -s lastpipe
cmd | while read -r line; do ((count++)); done
```

### ((expr)) returns exit 1 for zero

`((0))` has exit code 1. With `set -e` this kills the script.

With `set -uo pipefail` (no `-e`) this is safe. `((count++))` when count=0:
evaluates pre-increment (0), returns 1, THEN increments.

### set -u and empty arrays

`"${arr[@]}"` on empty array throws "unbound variable" in Bash < 4.4.
Fixed in Bash 5.3, but always initialize: `declare -a ARR=()`

### Variable scope in loops

`local` applies to entire function, not block/loop. Declare once:

``` bash
process() {
  local item dir status
  for item in "${ITEMS[@]}"; do
    dir="${BASE}/${item}"
  done
}
```

### Word splitting traps

- `${var}` is NOT `"$var"` (word splitting applies to unquoted)
- Don't use for-loops for newline-separated data (use `while read`)
- Don't assume paths are safe without validation

## Anti-patterns catalog

### Language

- `$(command)` when built-in exists -> use parameter expansion
- `echo` -> `printf`
- `expr` -> `$(( ))`
- `test` / `[ ]` -> `[[ ]]`
- `which` -> `command -v`
- `seq` -> `{1..n}` or `for (( ))`
- backticks -> `$( )`
- `let` -> `(( ))`

### Files

- `ls` in scripts -> globbing or arrays
- parsing `ls` output -> never
- `cat file | cmd` -> `cmd < file`
- temp files without mktemp -> `mktemp`

### Security

- `eval` -> never, use namerefs/assoc arrays
- `set -e` -> explicit checks
- unquoted `$var` -> `"$var"`
- `rm -rf` without validation -> guard with checks
- `cd` without return check -> `cd ... || exit`
- sourcing untrusted files -> never
- ignoring exit codes -> check important commands

### Structure

- global variables when local suffices -> `local`
- functions over 30 lines -> split
- nesting over 3 levels -> restructure
- excessive heredocs -> separate files
- fragile output parsing -> structured formats
