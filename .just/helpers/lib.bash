# shellcheck shell=bash disable=SC2034
# ── lib.bash — shared library for .just/helpers ─────────────────────────────
# SOURCED, never executed (no shebang on purpose). Carries the Bash 5.3 guard,
# terminal-default colors via tput, tiny utilities, terminal-size detection,
# and fast file-parse facts about the oh-my-forge repo. No JVM/network/expensive
# calls live here — everything must be safe on the bare-`just` splash path.

((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3))) || {
  printf 'error: GNU Bash >= 5.3 required, got %s\n' "$BASH_VERSION" >&2
  printf 'hint : brew install bash  (/opt/homebrew/bin must precede /bin in PATH)\n' >&2
  exit 1
}

set -o pipefail

LIB_DIR=$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)
REPO_ROOT=$(cd -- "${LIB_DIR}/../.." && pwd)
readonly LIB_DIR REPO_ROOT

# ── tiny utilities ───────────────────────────────────────────────────────────

has() { command -v "$1" > /dev/null 2>&1; }

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

is_tty() { [[ -t 1 ]]; }

# ── colors: terminal defaults via tput ONLY ──────────────────────────────────
# ANSI indexes 0-7 map to the user's terminal scheme — the single source of
# color truth. tput consults only $TERM (not isatty), so every cursor/screen
# op below is gated on the tty check or it pollutes piped output.

_ncolors=0
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  _ncolors=$(tput colors 2> /dev/null || printf 0)
fi
if ((_ncolors >= 8)); then
  C_RESET=$(tput sgr0) C_BOLD=$(tput bold) C_DIM=$(tput dim) C_REV=$(tput rev)
  C_RED=$(tput setaf 1) C_GREEN=$(tput setaf 2) C_YELLOW=$(tput setaf 3)
  C_BLUE=$(tput setaf 4) C_MAGENTA=$(tput setaf 5) C_CYAN=$(tput setaf 6)
else
  C_RESET='' C_BOLD='' C_DIM='' C_REV=''
  C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi

# ── terminal size ─────────────────────────────────────────────────────────────
# Precedence: COLUMNS/LINES env (test override) > stty on /dev/tty > tput >
# 80x24 floor. stty reports "0 0" on degenerate ptys — reject non-positives.
# Redirection order matters: stderr is silenced BEFORE the /dev/tty open.

_term_size() {
  local out stty_bin=stty
  local cols=0 lines=0
  has gstty && stty_bin=gstty
  if [[ ${COLUMNS:-0} -gt 0 && ${LINES:-0} -gt 0 ]]; then
    cols=${COLUMNS} lines=${LINES}
  elif out=$("${stty_bin}" size 2> /dev/null < /dev/tty) \
    && [[ ${out} =~ ^([0-9]+)\ ([0-9]+)$ ]]; then
    lines=${BASH_REMATCH[1]} cols=${BASH_REMATCH[2]}
  else
    cols=$(tput cols 2> /dev/null || printf 0)
    lines=$(tput lines 2> /dev/null || printf 0)
  fi
  ((cols > 0)) || cols=80
  ((lines > 0)) || lines=24
  TERM_COLS=${cols} TERM_LINES=${lines}
}

term_cols() {
  _term_size
  printf '%s' "${TERM_COLS}"
}

term_lines() {
  _term_size
  printf '%s' "${TERM_LINES}"
}

# ── tty input drain ──────────────────────────────────────────────────────────
# gum/lipgloss queries the terminal (DSR/OSC) when stdout is a tty; the
# terminal's replies land in OUR stdin and the next read -rsn1 eats the ESC,
# firing "any key → shell" instantly. Burst-drain stdin until ~100ms of quiet
# after every gum render, before every hotkey read loop.

drain_tty_input() {
  local junk
  while read -rsn1 -t 0.1 junk 2> /dev/null; do :; done
}

# ── fast repo facts (file-parse only) ────────────────────────────────────────

omf_count() {
  local kind=$1
  local -a m=()
  shopt -s nullglob
  case ${kind} in
    agents) m=("${REPO_ROOT}"/agents/*.md) ;;
    skills) m=("${REPO_ROOT}"/skills/*/SKILL.md) ;;
    commands) m=("${REPO_ROOT}"/commands/*.md) ;;
    templates) m=("${REPO_ROOT}"/templates/*.md) ;;
    *) m=() ;;
  esac
  shopt -u nullglob
  printf '%s' "${#m[@]}"
}

omf_catalog_version() {
  if has jq; then
    jq -r '.catalogVersion // "?"' "${REPO_ROOT}/catalog-manifest.json" 2> /dev/null \
      || printf '?'
  else
    printf '?'
  fi
}

git_branch() {
  git -C "${REPO_ROOT}" branch --show-current 2> /dev/null || printf '?'
}

git_dirty_count() {
  local n
  n=$(git -C "${REPO_ROOT}" status --porcelain 2> /dev/null | wc -l | tr -d '[:space:]')
  printf '%s' "${n:-0}"
}

git_last_commit() {
  git -C "${REPO_ROOT}" log -1 --format='%h %cs' 2> /dev/null || printf '?'
}

# ── recipe introspection (shared by menu.bash and fzf.bash) ──────────────────
# Emits TSV: name<TAB>group<TAB>doc<TAB>params. Param suffixes: `?` = has a
# default (skippable), `*` = variadic (kind star/plus — their default is null,
# so a default-only check would mis-label them required). just --dump
# attributes are a MIXED array (strings + {"group": ...} objects) — jq must
# split with strings/objects or index() explodes.

GROUP_ORDER=(umbrella meta md toml shell json files install clean util)

group_rank() {
  local g=$1 i
  for i in "${!GROUP_ORDER[@]}"; do
    if [[ ${GROUP_ORDER[i]} == "${g}" ]]; then
      printf '%s' "${i}"
      return 0
    fi
  done
  printf '%s' "${#GROUP_ORDER[@]}"
}

just_recipe_rows() {
  just --dump --dump-format json | jq -r '
    .recipes | to_entries[]
    | select(.key | startswith("_") | not)
    | select(.key != "default")
    | select([.value.attributes[]? | strings] | index("private") | not)
    | [ .key,
        (([.value.attributes[]? | objects | .group] | first) // "misc"),
        (.value.doc // ""),
        ([.value.parameters[]?
          | .name + (if .kind == "star" or .kind == "plus" then "*"
                     elif .default != null then "?"
                     else "" end)] | join(" "))
      ] | @tsv'
}

just_recipe_rows_sorted() { # GROUP_ORDER-sorted; unknown groups last
  local name group doc params
  while IFS=$'\t' read -r name group doc params; do
    printf '%02d\t%s\t%s\t%s\t%s\n' \
      "$(group_rank "${group}")" "${name}" "${group}" "${doc}" "${params}"
  done < <(just_recipe_rows) | sort -s -t $'\t' -k1,1 | cut -f2-
}
