# Script Architecture and Project Structure

How to structure Bash programs, from single scripts to multi-file projects.

## Contents

- [Script skeleton](#script-skeleton)
- [Phase-based execution](#phase-based-execution)
- [State tracking patterns](#state-tracking-patterns)
- [Project directory structure](#project-directory-structure)
- [Library organization](#library-organization)
- [GNU tools detection](#gnu-tools-detection)
- [Makefile template](#makefile-template)
- [Editor and project config](#editor-and-project-config)

## Script skeleton

Every script follows this 10-section structure in order:

```text
1.  Shebang + header comment block
2.  Bash version guard (case statement on BASH_VERSION)
3.  set -uo pipefail; IFS=$' \t\n' (reset IFS to default)
4.  Config section (constants, arrays)
5.  Color/formatting constants
6.  State tracking (associative + indexed arrays)
7.  Helper functions (log, err, warn, ok, confirm, hr)
8.  Domain functions (preflight, verify, process, summarize)
9.  main() that calls everything in phase order
10. main "$@" at bottom
```

Version guard:

- Always place at the very beginning of the file after the shebang

```bash
#!/usr/bin/env bash

# shellcheck disable=SC3028,SC3010
if [ -z "${BASH_VERSINFO+set}" ]; then
  echo >&2 'error: this script requires Bash'
  exit 1
fi
((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3))) || {
  printf >&2 'error: Bash 5.3+ required (found %s)\n' "$BASH_VERSION"
  exit 1
}

set -uo pipefail
IFS=$' \t\n'
```

Entry-point guard for files that double as libraries:

```bash
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
```

## Phase-based execution

Structure batch scripts as numbered phases with user gates:

```text
Phase 1: gather info (read-only, display to user)
  --> confirm gate
Phase 2: prepare (clean state, no mutations yet)
  --> confirm gate on failures
Phase 3: mutate (create branches, make changes)
Phase 4: summarize (show diff, show what will happen)
  --> confirm gate
Phase 5: commit (persist changes locally)
  --> confirm gate
Phase 6: finalize (merge, push, deploy)
  --> confirm gate
```

Rules:

- Each phase is idempotent or safely resumable
- User can abort at any gate without broken state
- Verify everything before mutating anything
- Separate "stage" from "commit" (user reviews staged changes)
- Separate "commit" from "push" (user approves before remote mutation)
- Track failures, skip failed items in later phases, report at end

## State tracking patterns

### Associative array as O(1) set

```bash
declare -A FAILED_SET=()
declare -a FAILED_REPOS=()    # keep ordered list for display

mark_failed() {
  FAILED_SET[$1]=1
  FAILED_REPOS+=("$1")
}

is_failed() { [[ -v FAILED_SET[$1] ]]; }
```

`[[ -v hash[key] ]]` is the correct way to test key existence (Bash 4.3+).

### Multiple tracking arrays

```bash
declare -a CHANGED=()    # items that were modified
declare -a CLEAN=()      # items already in desired state
declare -a FAILED=()     # items that errored
```

Lets the summary phase report cleanly and lets subsequent phases operate on the relevant subset only.

## Project directory structure

```text
project/
  bin/             main executables
  lib/             shared functions and libraries
  config/          configuration files
  snippets/        code snippet files
  tests/           bats test files (if testing enabled)
  docs/            documentation
  tmp/             temporary files (gitignored)
  .editorconfig    editor configuration
  .gitignore       git ignore patterns
  Makefile         build and development tasks
  README.md        user documentation
  README-DEV.md    developer documentation
```

## Library organization

```bash
# lib/common.bash - shared utilities
# lib/logging.bash - logging functions
# lib/config.bash - configuration handling

# source at top of main script
readonly SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
source "$SCRIPT_DIR/lib/common.bash"
source "$SCRIPT_DIR/lib/logging.bash"
```

Use prefixes for namespacing: `json_parse`, `fs_realpath`, `log_info`.

## GNU tools detection

```bash
detect_gnu_tools() {
  declare -gA GNU=()
  if [[ $OSTYPE == darwin* ]]; then
    GNU=([sed]=gsed [awk]=gawk [grep]=ggrep [find]=gfind [xargs]=gxargs)
  else
    GNU=([sed]=sed [awk]=awk [grep]=grep [find]=find [xargs]=xargs)
  fi
}

require_tool() {
  command -v "$1" >/dev/null || {
    printf 'error: required tool not found: %s\n' "$1" >&2
    exit 1
  }
}

ensure_deps() {
  local k
  for k in "${!GNU[@]}"; do
    require_tool "${GNU[$k]}"
  done
  command -v jq >/dev/null \
    || printf 'tip: install jq: brew install jq\n' >&2
  command -v shfmt >/dev/null \
    || printf 'tip: install shfmt: brew install shfmt\n' >&2
}

# optional capability checks
have_flock() { command -v flock >/dev/null; }
have_dev_tcp() { [[ -e /dev/tcp/localhost/1 ]] 2>/dev/null; }
```

## Makefile template

```makefile
.PHONY: help test lint format dev clean install

help:
	@echo "targets: test lint format dev clean install"

test:
	@if [[ -d tests/ ]]; then bats tests/; \
	else echo "no tests directory"; fi

lint:
	shellcheck -x *.bash

format:
	shfmt -w -i 2 -ci -sr *.bash

dev:
	@command -v shellcheck >/dev/null || { echo "brew install shellcheck"; exit 1; }
	@command -v shfmt >/dev/null || { echo "brew install shfmt"; exit 1; }
	@echo "ready"

install:
	install -m 755 bin/main.bash /usr/local/bin/main

clean:
	rm -rf build/ *.log tmp/
```

## Editor and project config

Always include `.editorconfig`:

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.bash]
indent_size = 2

[Makefile]
indent_style = tab
```

Keep `.gitignore` updated (include `tmp/`, `*.log`, build artifacts).

## Shellcheck directives

Add at the top of scripts (after shebang, before code) to enable useful optional checks:

```bash
# shellcheck enable=avoid-nullary-conditions
# shellcheck enable=add-default-case,check-extra-masked-returns
# shellcheck enable=check-set-e-suppressed,require-double-brackets
# shellcheck enable=check-unassigned-uppercase,deprecate-which
```

Also consider `shellharden` as a complementary tool: it auto-fixes quoting issues and prints the corrected script rather than just warning.

## Clean-environment shebang

To run scripts without inheriting the parent shell environment:

```bash
#!/usr/bin/env -iS -- bash
```

Useful for CI/CD or scripts that must not depend on user environment variables.

Testing with bats (only when explicitly requested):

```bash
#!/usr/bin/env bats

setup() {
  export TEST_TEMP_DIR
  TEST_TEMP_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
}

@test "function works" {
  run function_under_test "arg1" "arg2"
  [[ $status -eq 0 ]]
  [[ $output =~ "expected" ]]
}
```
