#!/usr/bin/env bash
# hist.bash -- omf hist: list `: ` forge prompts via the verbatim `forge-hist` fn.
# Usage: hist.bash [-a|--all] [-n COUNT] [PATTERN]
#
# The lister is the tuned zsh `forge-hist` function (vendored verbatim under
# vendor/). We NEVER reimplement it -- this adapter sources the vendored snippet
# in a clean zsh and calls `forge-hist` with the caller's args. The snippet also
# registers ZLE widgets / a C-f keybind at load (an interactive-shell concern);
# those load-time lines are inert here, so their stderr noise is discarded while
# the snippet is sourced. Override the snippet path with OMF_FORGE_HIST_SNIPPET.
set -euo pipefail
trap 'exit 130' INT TERM HUP

((BASH_VERSINFO[0] >= 5)) || {
  printf 'omf hist: requires Bash 5+\n' >&2
  exit 1
}

ADAPTERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNIPPET="${OMF_FORGE_HIST_SNIPPET:-$ADAPTERS_DIR/vendor/forge-history.zsh}"

command -v zsh > /dev/null 2>&1 \
  || {
    printf 'omf hist: zsh required (forge-hist is a zsh function)\n' >&2
    exit 127
  }
[[ -r "$SNIPPET" ]] \
  || {
    printf 'omf hist: history snippet not found: %s\n' "$SNIPPET" >&2
    exit 1
  }

# `zsh -f` skips the user rc (fast, hermetic) but keeps PATH so the optional
# sqlite3/fzf sources still resolve. $1 = snippet path, "${@:2}" = forge-hist args.
exec zsh -f -c 'source "$1" 2> /dev/null; forge-hist "${@:2}"' zsh "$SNIPPET" "$@"
