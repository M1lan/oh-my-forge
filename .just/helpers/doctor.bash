#!/usr/bin/env bash
# ── doctor.bash — dependency audit + project checks for oh-my-forge ─────────
# Modes:
#   (none)      full three-tier dep table + project checks; exit 1 if any
#               REQUIRED dep is missing or a project check fails (CI-runnable)
#   --summary   one-line status for the info splash
#   --factoid   the single most important fact, format: <problem> -- <fix>
#   --install   gum multi-select of missing deps → brew install

# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "${REPO_ROOT}" || exit 1
trap 'exit 130' INT TERM HUP

REQUIRED=(bash just rumdl taplo shellcheck shfmt prettier jq)
RECOMMENDED=(gum fzf bat rg editorconfig-checker yq)
OPTIONAL=(figlet fd eza)

declare -A PKG=(
  [rg]=ripgrep
)

declare -A WHY=(
  [bash]='GNU Bash >= 5.3 — every recipe and helper runs on it'
  [just]='the task runner itself'
  [rumdl]='Markdown linter/formatter (140 .md files)'
  [taplo]='TOML lint + fmt'
  [shellcheck]='shell static analysis (scripts/ + .just/helpers/)'
  [shfmt]='shell formatter'
  [prettier]='JSON format check'
  [jq]='JSON parsing for menus, doctor, manifest facts'
  [gum]='the `just menu` TUI + splash panels'
  [fzf]='the `just fzf` launcher, search, pickers'
  [bat]='syntax-highlighted previews'
  [rg]='live grep behind `just search`'
  # NOTE: dashed keys MUST be quoted or shfmt rewrites them as arithmetic
  # ([editorconfig-checker] → [editorconfig - checker]).
  ['editorconfig-checker']='indent/charset/EOL compliance gate'
  [yq]='agent frontmatter validation in scripts/doctor.sh'
  [figlet]='splash banner'
  [fd]='fast file listing behind `just pick`'
  [eza]='directory listings'
)

# ── checks ───────────────────────────────────────────────────────────────────

tool_ok() {
  local tool=$1
  if [[ ${tool} == bash ]]; then
    # Full major+minor guard: "bash 5" alone is NOT enough (need >= 5.3).
    local v
    v=$(bash -c 'printf "%s %s" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"')
    [[ ${v} =~ ^([0-9]+)\ ([0-9]+)$ ]] || return 1
    ((BASH_REMATCH[1] > 5 || (BASH_REMATCH[1] == 5 && BASH_REMATCH[2] >= 3)))
  else
    has "${tool}"
  fi
}

missing_in_tier() { # tier-array-name → newline-separated missing tools
  local -n _tier_ref=$1
  local t
  for t in "${_tier_ref[@]}"; do
    tool_ok "${t}" || printf '%s\n' "${t}"
  done
}

# Project checks: print "FAIL <description> -- <fix>" lines, one per failure.
project_failures() {
  local d sub h
  shopt -s nullglob
  for d in agents commands; do
    for sub in "${d}"/*/; do
      printf 'FAIL %s contains a subdirectory (forgecode loads flat only) -- flatten %s\n' "${d}/" "${sub}"
    done
  done
  for d in skills/*/; do
    [[ -f ${d}SKILL.md ]] \
      || printf 'FAIL %s has no SKILL.md -- add one or remove the directory\n' "${d}"
  done
  for h in .just/helpers/*.bash; do
    [[ ${h##*/} == lib.bash ]] && continue
    [[ -x ${h} ]] || printf 'FAIL %s not executable -- chmod +x %s\n' "${h}" "${h}"
  done
  shopt -u nullglob
  if has jq && ! jq -e . catalog-manifest.json > /dev/null 2>&1; then
    printf 'FAIL catalog-manifest.json does not parse -- jq . catalog-manifest.json\n'
  fi
  if [[ -e forge.yaml ]]; then
    printf 'FAIL forge.yaml present (v1 artifact, ignored by forgecode) -- scripts/migrate-from-v1.sh\n'
  fi
}

# ── output modes ─────────────────────────────────────────────────────────────

print_row() {
  local tool=$1 tier=$2
  local status mark color
  if tool_ok "${tool}"; then
    mark='✓' color=${C_GREEN} status='ok'
  else
    mark='✗' status="brew install ${PKG[${tool}]:-${tool}}"
    case ${tier} in
      REQUIRED) color=${C_RED} ;;
      *) color=${C_YELLOW} ;;
    esac
  fi
  printf '%s%s%s %-22s %-12s %-34s %s%s%s\n' \
    "${color}" "${mark}" "${C_RESET}" "${tool}" "${tier,,}" "${status}" \
    "${C_DIM}" "${WHY[${tool}]:-}" "${C_RESET}"
}

full_report() {
  local rc=0 tool line
  for tool in "${REQUIRED[@]}"; do print_row "${tool}" REQUIRED; done
  for tool in "${RECOMMENDED[@]}"; do print_row "${tool}" RECOMMENDED; done
  for tool in "${OPTIONAL[@]}"; do print_row "${tool}" OPTIONAL; done
  printf '\n'
  local -a fails=()
  mapfile -t fails < <(project_failures)
  if ((${#fails[@]} > 0)); then
    for line in "${fails[@]}"; do
      printf '%s✗ %s%s\n' "${C_RED}" "${line#FAIL }" "${C_RESET}"
    done
    rc=1
  else
    printf '%s✓ project checks: agents flat · skills have SKILL.md · manifest parses · no forge.yaml%s\n' \
      "${C_GREEN}" "${C_RESET}"
  fi
  local -a req_missing=()
  mapfile -t req_missing < <(missing_in_tier REQUIRED)
  if ((${#req_missing[@]} > 0)); then
    printf '%s✗ required deps missing: %s%s\n' "${C_RED}" "${req_missing[*]}" "${C_RESET}"
    rc=1
  fi
  return "${rc}"
}

summary() {
  local -a req_miss=() rec_miss=()
  mapfile -t req_miss < <(missing_in_tier REQUIRED)
  mapfile -t rec_miss < <(missing_in_tier RECOMMENDED)
  local proj='repo ok'
  [[ -n $(project_failures) ]] && proj='repo FAIL'
  printf 'deps %s/%s required · %s/%s recommended · %s\n' \
    "$((${#REQUIRED[@]} - ${#req_miss[@]}))" "${#REQUIRED[@]}" \
    "$((${#RECOMMENDED[@]} - ${#rec_miss[@]}))" "${#RECOMMENDED[@]}" "${proj}"
}

factoid() {
  local t fail dirty
  t=$(missing_in_tier REQUIRED | head -1)
  if [[ -n ${t} ]]; then
    printf '%s missing (required) -- brew install %s\n' "${t}" "${PKG[${t}]:-${t}}"
    return 0
  fi
  t=$(missing_in_tier RECOMMENDED | head -1)
  if [[ -n ${t} ]]; then
    printf '%s missing (recommended) -- brew install %s\n' "${t}" "${PKG[${t}]:-${t}}"
    return 0
  fi
  fail=$(project_failures | head -1)
  if [[ -n ${fail} ]]; then
    printf '%s\n' "${fail#FAIL }"
    return 0
  fi
  dirty=$(git_dirty_count)
  if ((dirty > 0)); then
    printf '%s dirty files in the tree -- just ci before committing\n' "${dirty}"
    return 0
  fi
  printf 'all green -- just ci is the full gate, just fix auto-repairs\n'
}

install_missing() {
  has gum || die 'gum required for --install (brew install gum)'
  local t out rc=0
  local -a missing=() choices=() pkgs=()
  mapfile -t missing < <(
    missing_in_tier REQUIRED
    missing_in_tier RECOMMENDED
    missing_in_tier OPTIONAL
  )
  ((${#missing[@]} > 0)) || {
    printf 'nothing missing — all tools installed\n'
    exit 0
  }
  out=$(gum choose --no-limit \
    --header 'install which? (space selects, enter confirms)' \
    "${missing[@]}") || rc=$?
  ((rc == 0)) && [[ -n ${out} ]] || exit 0
  mapfile -t choices <<< "${out}"
  for t in "${choices[@]}"; do
    pkgs+=("${PKG[${t}]:-${t}}")
  done
  gum spin --title "brew install ${pkgs[*]}" -- brew install "${pkgs[@]}"
}

case ${1:-} in
  --summary) summary ;;
  --factoid) factoid ;;
  --install) install_missing ;;
  *) full_report ;;
esac
