#!/usr/bin/env bash
# resume.bash -- omf resume: launch the verbatim `fcr` forge-conversation picker.
# Usage: resume.bash
#
# The picker is the tuned zsh `fcr` function (vendored verbatim under vendor/).
# We NEVER reimplement it -- this adapter is a thin launcher that sources the
# vendored snippet in a clean zsh and hands control to `fcr`, which ends by
# exec-ing `forge --conversation-id <uuid>`. Override the snippet location with
# OMF_FCR_SNIPPET (e.g. to point at the canonical ~/.config copy).
set -euo pipefail
trap 'exit 130' INT TERM HUP

((BASH_VERSINFO[0] >= 5)) || {
  printf 'omf resume: requires Bash 5+\n' >&2
  exit 1
}

ADAPTERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNIPPET="${OMF_FCR_SNIPPET:-$ADAPTERS_DIR/vendor/forge-conversation-resume.zsh}"

command -v zsh > /dev/null 2>&1 \
  || {
    printf 'omf resume: zsh required (fcr is a zsh picker)\n' >&2
    exit 127
  }
[[ -r "$SNIPPET" ]] \
  || {
    printf 'omf resume: picker snippet not found: %s\n' "$SNIPPET" >&2
    exit 1
  }

# `zsh -f` skips the user rc (fast, hermetic) while keeping PATH so fcr finds
# forge/fzf/awk/mktemp. Positional $1 carries the snippet path into the -c body.
exec zsh -f -c 'source "$1" && fcr' zsh "$SNIPPET"
