#!/usr/bin/env bash
# ── search.bash — live ripgrep → fzf → bat → $EDITOR ────────────────────────
# Starts in rg-live mode (every keystroke re-runs rg). ctrl-f toggles to
# fuzzy-filtering the frozen result set and back. Enter opens the hit in
# $EDITOR at the matching line.

# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "${REPO_ROOT}" || exit 1
trap 'exit 130' INT TERM HUP

has rg || die 'rg required (brew install ripgrep)'
has fzf || die 'fzf required (brew install fzf)'

state_rg="${TMPDIR:-/tmp}/omf-rg-fzf-r"
state_fz="${TMPDIR:-/tmp}/omf-rg-fzf-f"
rm -f "${state_rg}" "${state_fz}"

RG='rg --column --line-number --no-heading --color=always --smart-case'
query="${*:-}"

preview_cmd='bat --color=always --style=numbers --highlight-line {2} {1} 2>/dev/null || sed -n 1,200p {1}'
has bat || preview_cmd='sed -n 1,200p {1}'

rc=0
sel=$(fzf --ansi --disabled --query "${query}" \
  --prompt 'rg> ' --delimiter : \
  --header 'ctrl-f toggles rg ↔ fuzzy · enter opens in $EDITOR' \
  --bind "start:reload:${RG} -- {q} || true" \
  --bind "change:reload:sleep 0.05; ${RG} -- {q} || true" \
  --bind "ctrl-f:transform:[[ ! \${FZF_PROMPT} == 'rg> ' ]] \
&& echo \"rebind(change)+change-prompt(rg> )+disable-search+transform-query:echo {q} > ${state_fz}; cat ${state_rg}\" \
|| echo \"unbind(change)+change-prompt(fzf> )+enable-search+transform-query:echo {q} > ${state_rg}; cat ${state_fz}\"" \
  --preview "${preview_cmd}" \
  --preview-window 'right,55%,+{2}+3/2,~3,<70(down,40%)' \
  --border rounded --border-label ' search ' \
  --color 'border:6,label:6,header:3,prompt:6,pointer:6,marker:2,spinner:6,info:8,separator:8,scrollbar:8' \
  --color 'hl:6,hl+:6,fg+:-1,bg+:-1') || rc=$?
rm -f "${state_rg}" "${state_fz}"
((rc == 0)) && [[ -n ${sel} ]] || exit 0

file=${sel%%:*}
rest=${sel#*:}
line=${rest%%:*}
exec "${EDITOR:-nano}" "+${line}" "${file}"
