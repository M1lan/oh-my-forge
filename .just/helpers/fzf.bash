#!/usr/bin/env bash
# ── fzf.bash — the FZF launcher: flat power surface ─────────────────────────
# fzf-only (NEVER invokes gum — that identity lives in menu.bash). Every
# recipe in one dense alt-screen pane with an always-on source preview.
# --multi: Tab-select N recipes → batch-runs them in list order, stopping at
# the first failure. No param prompting — bare exec; just's own usage error
# is the feedback. Identity test: menu PROMPTS for params; fzf MULTI-SELECTS.

# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "${REPO_ROOT}" || exit 1
trap 'exit 130' INT TERM HUP

has fzf || die 'fzf required (brew install fzf) — try `just menu` or `just help` instead'
has jq || die 'jq required (brew install jq)'

# ── rows: ANSI-tinted recipe list (re-entrant for ctrl-r reload) ─────────────
# Deliberately emits ANSI into a pipe (fzf --ansi consumes it and strips the
# codes from OUTPUT, so {1}-extraction stays safe). lib.bash colors are
# tty-gated, so rows() builds its own set — tput consults only $TERM.

rows() {
  local f_reset='' f_green='' f_cyan='' f_yellow='' f_magenta='' f_blue='' f_red='' f_dim=''
  if [[ -z ${NO_COLOR:-} ]]; then
    f_reset=$(tput sgr0 2> /dev/null || true)
    f_green=$(tput setaf 2 2> /dev/null || true)
    f_cyan=$(tput setaf 6 2> /dev/null || true)
    f_yellow=$(tput setaf 3 2> /dev/null || true)
    f_magenta=$(tput setaf 5 2> /dev/null || true)
    f_blue=$(tput setaf 4 2> /dev/null || true)
    f_red=$(tput setaf 1 2> /dev/null || true)
    f_dim=$(tput dim 2> /dev/null || true)
  fi
  local name group doc params tint
  while IFS=$'\t' read -r name group doc params; do
    case ${group} in
      umbrella) tint=${f_green} ;;
      md | toml | shell | json | files) tint=${f_magenta} ;;
      install) tint=${f_blue} ;;
      clean) tint=${f_red} ;;
      util) tint=${f_cyan} ;;
      meta) tint=${f_dim} ;;
      *) tint=${f_yellow} ;;
    esac
    printf '%-18s %s%-10s%s %s\n' "${name}" "${tint}" "[${group}]" "${f_reset}" "${doc}"
  done < <(just_recipe_rows_sorted)
}

if [[ ${1:-} == --rows ]]; then
  rows
  exit 0
fi

# ── the launcher ─────────────────────────────────────────────────────────────

preview_cmd='just --show {1} 2>/dev/null | bat --language=make --style=plain --color=always 2>/dev/null || just --show {1}'
has bat || preview_cmd='just --show {1}'

rc=0
sel=$(rows | fzf --ansi --multi --style=full \
  --prompt '  ❯ ' --pointer '▌' \
  --header 'tab multi-select · enter runs in order (stop on first failure) · ctrl-r reload · ctrl-/ preview' \
  --bind 'tab:toggle+down,shift-tab:toggle+up' \
  --bind "ctrl-r:reload:'$0' --rows" \
  --bind 'ctrl-/:toggle-preview' \
  --preview "${preview_cmd}" \
  --preview-window 'right,55%,<70(down,40%)' \
  --border rounded --border-label ' oh-my-forge ' \
  --list-label ' recipes ' --input-label ' filter ' --preview-label ' source ' \
  --color 'border:6,label:6,header:3,prompt:6,pointer:6,marker:2,spinner:6,info:8,separator:8,scrollbar:8' \
  --color 'hl:6,hl+:6,fg+:-1,bg+:-1') || rc=$?
((rc == 0)) && [[ -n ${sel} ]] || exit 0

mapfile -t selected <<< "${sel}"
for line in "${selected[@]}"; do
  read -r name _ <<< "${line}"
  printf '%s──▶ just %s%s\n' "${C_CYAN}" "${name}" "${C_RESET}"
  rc=0
  just "${name}" || rc=$?
  if ((rc != 0)); then
    printf '%s✗ just %s failed (exit %s) — batch stopped%s\n' \
      "${C_RED}" "${name}" "${rc}" "${C_RESET}" >&2
    exit "${rc}"
  fi
done
