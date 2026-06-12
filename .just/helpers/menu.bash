#!/usr/bin/env bash
# ── menu.bash — the gum launcher: guided command builder ────────────────────
# gum-only (NEVER invokes fzf — that identity lives in fzf.bash). For someone
# who does NOT know the recipe name: filter the grouped list, see the recipe
# source, get prompted for each parameter, confirm, run.
# Identity test: menu PROMPTS for params; fzf MULTI-SELECTS.

# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "${REPO_ROOT}" || exit 1
trap 'exit 130' INT TERM HUP

has gum || die 'gum required (brew install gum) — try `just fzf` or `just help` instead'
has jq || die 'jq required (brew install jq)'
# Guard the while-true loop: gum filter fails instantly without a tty, which
# would otherwise spin hot (rc=1 → continue → rc=1 → …).
is_tty || die 'menu is interactive — use `just help` in non-tty contexts'

# ── build the item list once (self-updating: read from `just --dump`) ────────
# Grouping is a [group] COLUMN on every real item — never separator lines
# (separators are selectable and picking one is a broken no-op).

declare -A PARAMS_OF=()
ITEMS=()
while IFS=$'\t' read -r name group doc params; do
  PARAMS_OF[${name}]=${params}
  ITEMS+=("$(printf '%-18s %-10s %s' "${name}" "[${group}]" "${doc}")")
done < <(just_recipe_rows_sorted)
ITEMS+=("$(printf '%-18s %-10s %s' 'quit' '[meta]' 'leave the menu')")

prompt_params() { # recipe-name → fills the global args array; rc 130 = cancel
  local recipe=$1 p pname val rc
  local -a plist=() words=()
  args=()
  read -ra plist <<< "${PARAMS_OF[${recipe}]:-}"
  for p in "${plist[@]+"${plist[@]}"}"; do
    case ${p} in
      *'?')
        pname=${p%?}
        rc=0
        val=$(gum input --prompt '  ❯ ' --prompt.foreground 6 --cursor.foreground 6 \
          --placeholder "${pname} — has a default; empty keeps it") || rc=$?
        ((rc != 0)) && return 130
        [[ -z ${val} ]] && break # just fills the remaining defaults
        args+=("${val}")
        ;;
      *'*')
        pname=${p%?}
        rc=0
        val=$(gum input --prompt '  ❯ ' --prompt.foreground 6 --cursor.foreground 6 \
          --placeholder "${pname} — variadic, space-separated; empty skips") || rc=$?
        ((rc != 0)) && return 130
        if [[ -n ${val} ]]; then
          read -ra words <<< "${val}"
          args+=("${words[@]+"${words[@]}"}")
        fi
        ;;
      *)
        rc=0
        val=$(gum input --prompt '  ❯ ' --prompt.foreground 6 --cursor.foreground 6 \
          --placeholder "${p} — required") || rc=$?
        ((rc != 0)) && return 130
        args+=("${val}")
        ;;
    esac
  done
  return 0
}

header_box() {
  gum style --border rounded --border-foreground 6 --padding '0 1' \
    "$(printf '%soh-my-forge%s\n%sguided command builder — esc esc quits · `just fzf` is the power launcher%s' \
      "${C_BOLD}${C_CYAN}" "${C_RESET}" "${C_DIM}" "${C_RESET}")"
}

declare -a args=()
while true; do
  is_tty && clear # TUI redraws, doesn't scroll
  header_box
  height=$(($(term_lines) - 12))
  ((height < 8)) && height=8
  rc=0
  choice=$(printf '%s\n' "${ITEMS[@]}" \
    | gum filter --no-fuzzy --reverse --height="${height}" \
      --placeholder='type a recipe…' --indicator='▌' \
      --indicator.foreground 6 --match.foreground 6 \
      --header 'recipe  [group]  description' --header.foreground 3 \
      --prompt '  › ' --prompt.foreground 6) || rc=$?
  ((rc == 130)) && exit 0 # esc esc / ctrl-c — leave
  ((rc != 0)) && continue # no match — re-render
  read -r name _ <<< "${choice}"
  [[ ${name} == quit ]] && exit 0

  is_tty && clear
  # bat has NO just grammar — --language=make gives real highlighting on
  # Justfile bodies; keep the plain fallback.
  if has bat; then
    just --show "${name}" | bat --language=make --style=plain --color=always 2> /dev/null \
      || just --show "${name}"
  else
    just --show "${name}"
  fi
  printf '\n'

  prompt_params "${name}" || continue # cancel during params → back to menu

  cmdline="just ${name}"
  ((${#args[@]} > 0)) && cmdline+=" ${args[*]}"
  rc=0
  gum confirm --prompt.foreground 6 "run: ${cmdline} ?" || rc=$?
  ((rc == 130)) && exit 130
  ((rc != 0)) && continue # declined → back to menu
  exec just "${name}" "${args[@]+"${args[@]}"}"
done
