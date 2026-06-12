#!/usr/bin/env bash
# ── info-screen.bash — bare-`just` splash for oh-my-forge ───────────────────
# Bare `just` ALWAYS lands here. Degradation chain: non-tty OR cols<78 OR
# lines<24 OR no gum → the --static render (same screen, no countdown) —
# NEVER the bare recipe list (that lives on `just help`).
# Keys during countdown: ⏎/m → menu · f → fzf · any other key → shell now.
# Timeout → one frugal factoid (doctor.bash --factoid) + exit 0.

# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "${REPO_ROOT}" || exit 1

restore() { is_tty && tput cnorm; }
trap 'restore; exit 130' INT TERM HUP

# ── banner ───────────────────────────────────────────────────────────────────

banner() {
  local fig line i=0
  local -a ramp=("${C_CYAN}" "${C_CYAN}" "${C_BLUE}" "${C_BLUE}" "${C_GREEN}")
  if has figlet; then
    fig=$(figlet -f smslant 'oh-my-forge' 2> /dev/null) \
      || fig=$(figlet -f slant 'oh-my-forge' 2> /dev/null) \
      || fig=$(figlet 'oh-my-forge' 2> /dev/null) \
      || fig='oh-my-forge'
  else
    fig='── oh-my-forge ──'
  fi
  while IFS= read -r line; do
    printf '  %s%s%s\n' "${ramp[i % ${#ramp[@]}]}" "${line}" "${C_RESET}"
    ((i++)) || true
  done <<< "${fig}"
}

# ── panel content (plain text — boxing is gum's job) ─────────────────────────

panel_pack() {
  printf '%sPACK%s\n' "${C_BOLD}${C_CYAN}" "${C_RESET}"
  printf 'agents     %s\n' "$(omf_count agents)"
  printf 'skills     %s\n' "$(omf_count skills)"
  printf 'commands   %s\n' "$(omf_count commands)"
  printf 'templates  %s\n' "$(omf_count templates)"
  printf 'catalog    v%s' "$(omf_catalog_version)"
}

panel_repo() {
  printf '%sREPO%s\n' "${C_BOLD}${C_CYAN}" "${C_RESET}"
  printf 'branch   %s\n' "$(git_branch)"
  printf 'dirty    %s files\n' "$(git_dirty_count)"
  printf 'commit   %s\n' "$(git_last_commit)"
  printf '%s' "$("${LIB_DIR}/doctor.bash" --summary)"
}

panel_verbs() {
  printf '%sVERBS%s\n' "${C_BOLD}${C_CYAN}" "${C_RESET}"
  printf 'just ci      full gate (doctor+check)\n'
  printf 'just fix     auto-repair everything\n'
  printf 'just doctor  dep audit (+ --install)\n'
  printf 'just help    flat recipe list'
}

hotkeys_text() {
  printf '⏎ / m  menu (guided)   ·   f  fzf (multi-run)   ·   any other key  shell'
}

# ── renderers ─────────────────────────────────────────────────────────────────

render_gum() {
  local cols=$1 w p1 p2 p3 keys
  if ((cols >= 130)); then
    w=$(((cols - 12) / 3))
    ((w > 44)) && w=44
  elif ((cols >= 96)); then
    w=$(((cols - 10) / 2))
    ((w > 50)) && w=50
  else
    w=$((cols - 8))
    ((w > 60)) && w=60
  fi
  p1=$(gum style --border rounded --border-foreground 6 --padding '0 1' --width "${w}" "$(panel_pack)")
  p2=$(gum style --border rounded --border-foreground 6 --padding '0 1' --width "${w}" "$(panel_repo)")
  p3=$(gum style --border rounded --border-foreground 6 --padding '0 1' --width "${w}" "$(panel_verbs)")
  if ((cols >= 130)); then
    gum join --horizontal --align top "${p1}" "${p2}" "${p3}"
  elif ((cols >= 96)); then
    gum join --horizontal --align top "${p1}" "${p2}"
    printf '%s\n' "${p3}"
  else
    printf '%s\n%s\n%s\n' "${p1}" "${p2}" "${p3}"
  fi
  # The ONE thick yellow box — the hi-viz hotkey strip.
  keys=$(gum style --border thick --border-foreground 3 --padding '0 1' "$(hotkeys_text)")
  printf '%s\n' "${keys}"
}

render_plain() {
  printf '\n'
  panel_pack
  printf '\n\n'
  panel_repo
  printf '\n\n'
  panel_verbs
  printf '\n\n%s\n' "$(hotkeys_text)"
}

# ── countdown ─────────────────────────────────────────────────────────────────

countdown() {
  local secs=${JUST_SPLASH_SECS:-5} rc key
  is_tty && tput civis
  drain_tty_input
  while ((secs > 0)); do
    is_tty && tput el
    printf '\r  %s %d %s  ⏎/m menu · f fzf · any other key → shell ' \
      "${C_REV}" "${secs}" "${C_RESET}"
    rc=0 key=''
    read -rsn1 -t 1 key || rc=$?
    if ((rc > 128)); then # timeout → next tick
      ((secs--)) || true
      continue
    fi
    if ((rc == 1)); then # EOF → stop counting down
      break
    fi
    case ${key} in
      '' | m)
        restore
        printf '\n'
        exec just menu
        ;;
      f)
        restore
        printf '\n'
        exec just fzf
        ;;
      *)
        restore
        printf '\n'
        exit 0
        ;;
    esac
  done
  restore
  printf '\n  %s\n' "$("${LIB_DIR}/doctor.bash" --factoid)"
  exit 0
}

# ── main ──────────────────────────────────────────────────────────────────────

static=0
[[ ${1:-} == --static ]] && static=1

_term_size
if is_tty && has gum && ((TERM_COLS >= 78 && TERM_LINES >= 24)); then
  is_tty && clear
  banner
  render_gum "${TERM_COLS}"
  ((static)) && exit 0
  drain_tty_input # gum/lipgloss DSR/OSC replies land in OUR stdin — drain first
  countdown
else
  banner
  render_plain
  exit 0
fi
