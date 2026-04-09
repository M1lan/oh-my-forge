#!/usr/bin/env bash
# oh-my-forge installer
#
# Installs agents, skills, commands, and templates from an oh-my-forge
# checkout into either a global forge directory ($HOME/forge) or a
# project-local one (./.forge).
#
# Usage:
#   ./scripts/install.sh [--global | --project DIR] [--dry-run] [--force]
#                        [--agents] [--skills] [--commands] [--templates]
#                        [--with-mcp-example] [--with-toml-example]
#                        [--backup-dir DIR]
#
# Default target is --global.
# Default component set is --agents --skills --commands --templates.
# Exits non-zero on any error.

set -euo pipefail
IFS=$'\n\t'

# ---------- Locate repo root ----------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMF_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# ---------- Defaults ----------
MODE="global" # global | project
PROJECT_DIR=""
DRY_RUN=false
FORCE=false
DO_AGENTS=false
DO_SKILLS=false
DO_COMMANDS=false
DO_TEMPLATES=false
WITH_MCP_EXAMPLE=false
WITH_TOML_EXAMPLE=false
EXPLICIT_COMPONENTS=false
BACKUP_DIR=""

# ---------- Colours (only when stdout is a tty) ----------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_DIM='\033[2m'
  C_BOLD='\033[1m'
  C_GREEN='\033[32m'
  C_YELLOW='\033[33m'
  C_RED='\033[31m'
  C_BLUE='\033[34m'
else
  C_RESET=''
  C_DIM=''
  C_BOLD=''
  C_GREEN=''
  C_YELLOW=''
  C_RED=''
  C_BLUE=''
fi

info() { printf '%bINFO%b %s\n' "${C_BLUE}${C_BOLD}" "${C_RESET}" "$*"; }
ok() { printf '%bOK%b   %s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}" "$*"; }
warn() { printf '%bWARN%b %s\n' "${C_YELLOW}${C_BOLD}" "${C_RESET}" "$*" >&2; }
err() { printf '%bERR%b  %s\n' "${C_RED}${C_BOLD}" "${C_RESET}" "$*" >&2; }
die() {
  err "$*"
  exit 1
}

usage() {
  cat << 'EOF'
oh-my-forge installer

Usage:
  ./scripts/install.sh [options]

Target (pick one):
  --global              Install to $HOME/forge (default)
  --project DIR         Install to DIR/.forge (DIR defaults to .)

Component selection (default: all of these):
  --agents              Install agents
  --skills              Install skills
  --commands            Install commands (if the repo ships any)
  --templates           Install template overrides (if the repo ships any)

Examples to drop into the target root (off by default, opt-in):
  --with-mcp-example    Copy .mcp.json.example into the target root
  --with-toml-example   Copy .forge.toml.example into the target root

Other:
  --dry-run             Print what would happen without touching the filesystem
  --force               Overwrite existing files without prompting
  --backup-dir DIR      Where to put backups of overwritten files
                        (default: <target>/.omf-backup-YYYYMMDD-HHMMSS)
  -h, --help            Show this help

The installer NEVER writes outside the chosen target directory. Run with
--dry-run first if you are not sure.
EOF
}

# ---------- Argument parsing ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      MODE="global"
      shift
      ;;
    --project)
      MODE="project"
      PROJECT_DIR="${2:-}"
      [[ -z "$PROJECT_DIR" ]] && die "--project requires a DIR"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --agents)
      DO_AGENTS=true
      EXPLICIT_COMPONENTS=true
      shift
      ;;
    --skills)
      DO_SKILLS=true
      EXPLICIT_COMPONENTS=true
      shift
      ;;
    --commands)
      DO_COMMANDS=true
      EXPLICIT_COMPONENTS=true
      shift
      ;;
    --templates)
      DO_TEMPLATES=true
      EXPLICIT_COMPONENTS=true
      shift
      ;;
    --with-mcp-example)
      WITH_MCP_EXAMPLE=true
      shift
      ;;
    --with-toml-example)
      WITH_TOML_EXAMPLE=true
      shift
      ;;
    --backup-dir)
      BACKUP_DIR="${2:-}"
      [[ -z "$BACKUP_DIR" ]] && die "--backup-dir requires a DIR"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown argument: $1 (try --help)" ;;
  esac
done

# Default all components on when the user didn't specify any
if [[ "$EXPLICIT_COMPONENTS" == false ]]; then
  DO_AGENTS=true
  DO_SKILLS=true
  DO_COMMANDS=true
  DO_TEMPLATES=true
fi

# ---------- Resolve target ----------
case "$MODE" in
  global)
    TARGET_ROOT="${HOME}/forge"
    ;;
  project)
    PROJECT_DIR="${PROJECT_DIR:-.}"
    [[ -d "$PROJECT_DIR" ]] || die "project dir does not exist: $PROJECT_DIR"
    TARGET_ROOT="$(cd -- "$PROJECT_DIR" && pwd)/.forge"
    ;;
esac

# Guard against nuking the repo itself if someone runs this from inside a checkout
if [[ "$TARGET_ROOT" == "$OMF_DIR" || "$TARGET_ROOT" == "$OMF_DIR/"* ]]; then
  die "refusing to install into the oh-my-forge repo itself ($TARGET_ROOT)"
fi

# ---------- Tool check ----------
need() { command -v "$1" > /dev/null 2>&1 || die "required tool missing: $1"; }
need find
need rsync

# ---------- Banner ----------
printf '%b===========================================%b\n' "$C_BOLD" "$C_RESET"
printf '%b oh-my-forge installer %b\n' "$C_BOLD" "$C_RESET"
printf '%b===========================================%b\n' "$C_BOLD" "$C_RESET"
info "Source:  ${C_DIM}${OMF_DIR}${C_RESET}"
info "Target:  ${C_DIM}${TARGET_ROOT}${C_RESET}"
info "Mode:    ${MODE}"
info "Dry run: ${DRY_RUN}"

# ---------- Plan & confirm ----------
components=()
$DO_AGENTS && components+=("agents")
$DO_SKILLS && components+=("skills")
$DO_COMMANDS && [[ -d "$OMF_DIR/commands" ]] && components+=("commands")
$DO_TEMPLATES && [[ -d "$OMF_DIR/templates" ]] && components+=("templates")
info "Components: ${components[*]:-none}"

# ---------- Run helper ----------
run() {
  if $DRY_RUN; then
    printf '%b[dry-run]%b %s\n' "$C_DIM" "$C_RESET" "$*"
  else
    eval "$*"
  fi
}

# ---------- Prepare backup dir ----------
if [[ -z "$BACKUP_DIR" ]]; then
  BACKUP_DIR="${TARGET_ROOT}/.omf-backup-$(date +%Y%m%d-%H%M%S)"
fi

need_backup=false

# ---------- Copy helpers ----------
# Agents and commands are flat (forgecode does not recurse into subdirectories
# for either). Skills are one-level deep (<name>/SKILL.md).
ensure_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    run "mkdir -p \"$d\""
  fi
}

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" ]]; then
    need_backup=true
    local rel="${target#"$TARGET_ROOT"/}"
    local dest="$BACKUP_DIR/$rel"
    run "mkdir -p \"$(dirname "$dest")\""
    run "cp -a \"$target\" \"$dest\""
  fi
}

# Flat-copy: all *.md under SRC are copied to DST at the top level.
# Collision detection: if two source files share the same basename, abort.
install_flat_md() {
  local src="$1" dst="$2" label="$3"
  [[ -d "$src" ]] || {
    info "skipping $label (no $src)"
    return
  }
  info "installing $label -> $dst"
  ensure_dir "$dst"

  # Collision detection
  local seen
  seen="$(mktemp -t omf-inst.XXXXXX)"
  # Inline cleanup rather than a RETURN trap (trap fires after locals are gone under `set -u`).
  local dup=0
  while IFS= read -r -d '' f; do
    local base
    base="$(basename "$f")"
    if grep -Fxq "$base" "$seen" 2> /dev/null; then
      err "collision: two sources share basename $base (second: $f)"
      dup=1
    else
      printf '%s\n' "$base" >> "$seen"
    fi
  done < <(find "$src" -type f -name '*.md' -print0)

  if [[ $dup -ne 0 ]]; then
    rm -f "$seen"
    die "aborting due to filename collisions in $label"
  fi

  # Install each file
  while IFS= read -r -d '' f; do
    local base
    base="$(basename "$f")"
    local target="$dst/$base"
    if [[ -e "$target" ]]; then
      if ! $FORCE && ! $DRY_RUN; then
        backup_if_exists "$target"
      fi
    fi
    run "install -m 0644 \"$f\" \"$target\""
  done < <(find "$src" -type f -name '*.md' -print0)
  rm -f "$seen"
  ok "$label installed"
}

# Skills: preserves the <name>/ subdirectory layout but refuses to walk deeper
# than one level.
install_skills() {
  local src="$1" dst="$2"
  [[ -d "$src" ]] || {
    info "skipping skills (no $src)"
    return
  }
  info "installing skills -> $dst"
  ensure_dir "$dst"
  for skill_dir in "$src"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    local target="$dst/$name"
    if [[ -e "$target" ]] && ! $FORCE && ! $DRY_RUN; then
      backup_if_exists "$target"
      run "rm -rf \"$target\""
    fi
    run "mkdir -p \"$target\""
    run "rsync -a --delete \"$skill_dir\" \"$target/\""
  done
  ok "skills installed"
}

# Commands = flat .md
install_commands() {
  install_flat_md "$OMF_DIR/commands" "$TARGET_ROOT/commands" "commands"
}

install_templates() {
  local src="$OMF_DIR/templates" dst="$TARGET_ROOT/templates"
  [[ -d "$src" ]] || {
    info "skipping templates (no $src)"
    return
  }
  info "installing templates -> $dst"
  ensure_dir "$dst"
  run "rsync -a \"$src/\" \"$dst/\""
  ok "templates installed"
}

install_mcp_example() {
  local src="$OMF_DIR/.mcp.json.example" dst="$TARGET_ROOT/.mcp.json.example"
  [[ -f "$src" ]] || {
    warn "no $src — skipping --with-mcp-example"
    return
  }
  info "installing .mcp.json.example -> $dst"
  [[ -e "$dst" ]] && ! $FORCE && ! $DRY_RUN && backup_if_exists "$dst"
  run "install -m 0644 \"$src\" \"$dst\""
  ok ".mcp.json.example installed (remember to review before renaming)"
}

install_toml_example() {
  local src="$OMF_DIR/.forge.toml" dst="$TARGET_ROOT/.forge.toml.example"
  [[ -f "$src" ]] || {
    warn "no $src — skipping --with-toml-example"
    return
  }
  info "installing .forge.toml.example -> $dst"
  [[ -e "$dst" ]] && ! $FORCE && ! $DRY_RUN && backup_if_exists "$dst"
  run "install -m 0644 \"$src\" \"$dst\""
  ok ".forge.toml.example installed (review before renaming to .forge.toml)"
}

# ---------- Go ----------
ensure_dir "$TARGET_ROOT"

if $DO_AGENTS; then
  install_flat_md "$OMF_DIR/agents" "$TARGET_ROOT/agents" "agents"
fi

if $DO_SKILLS; then
  install_skills "$OMF_DIR/skills" "$TARGET_ROOT/skills"
fi

if $DO_COMMANDS; then
  install_commands
fi

if $DO_TEMPLATES; then
  install_templates
fi

$WITH_MCP_EXAMPLE && install_mcp_example
$WITH_TOML_EXAMPLE && install_toml_example

# ---------- Summary ----------
printf '\n'
if $need_backup; then
  info "backups saved to: ${C_DIM}${BACKUP_DIR}${C_RESET}"
fi

if $DRY_RUN; then
  ok "dry run complete — no files were written"
else
  ok "install complete: ${TARGET_ROOT}"
fi

cat << EOF

Next steps:
  1. ${C_BOLD}Review the installed files${C_RESET} at $TARGET_ROOT
  2. ${C_BOLD}Run the doctor:${C_RESET} ${OMF_DIR}/scripts/doctor.sh
  3. ${C_BOLD}Start forge${C_RESET} in your target working directory
  4. Uninstall if needed: ${OMF_DIR}/scripts/uninstall.sh
EOF
