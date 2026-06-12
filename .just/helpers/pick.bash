#!/usr/bin/env bash
# ── pick.bash — fzf pickers: file → $EDITOR, branch → git switch ────────────
# Usage: pick.bash file | pick.bash branch

# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "${REPO_ROOT}" || exit 1
trap 'exit 130' INT TERM HUP

has fzf || die 'fzf required (brew install fzf)'

FZF_COLORS='border:6,label:6,header:3,prompt:6,pointer:6,marker:2,spinner:6,info:8,separator:8,scrollbar:8,hl:6,hl+:6,fg+:-1,bg+:-1'

pick_file() {
  local rc=0 sel
  local -a lister
  if has fd; then
    lister=(fd --type f --hidden --exclude .git --exclude .jj)
  else
    lister=(git ls-files)
  fi
  local preview='bat --color=always --style=numbers --line-range=:500 {}'
  has bat || preview='sed -n 1,200p {}'
  sel=$("${lister[@]}" \
    | fzf --prompt '  ❯ ' --border rounded --border-label ' pick a file ' \
      --color "${FZF_COLORS}" \
      --preview "${preview}") || rc=$?
  ((rc == 0)) && [[ -n ${sel} ]] || exit 0
  exec "${EDITOR:-nano}" "${sel}"
}

pick_branch() {
  local rc=0 sel
  sel=$(git branch --all --format='%(refname:short)' \
    | rg -v 'HEAD' \
    | fzf --prompt '  ❯ ' --border rounded --border-label ' switch branch ' \
      --color "${FZF_COLORS}" \
      --preview 'git log --oneline --color=always -15 {}') || rc=$?
  ((rc == 0)) && [[ -n ${sel} ]] || exit 0
  exec git switch "${sel#origin/}"
}

case ${1:-file} in
  file) pick_file ;;
  branch) pick_branch ;;
  *) die "unknown mode: ${1} (file|branch)" ;;
esac
