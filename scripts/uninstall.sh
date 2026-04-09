#!/usr/bin/env bash
# oh-my-forge uninstaller
#
# Removes files installed by scripts/install.sh. Uses the shipped
# catalog-manifest.json where possible; otherwise falls back to removing
# all *.md files in agents/, all <name>/SKILL.md in skills/, and all
# *.md in commands/ under the target root. Always creates a backup first.
#
# Usage:
#   ./scripts/uninstall.sh [--global | --project DIR] [--dry-run] [--force]

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMF_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MODE="global"
PROJECT_DIR=""
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      MODE="global"
      shift
      ;;
    --project)
      MODE="project"
      PROJECT_DIR="${2:-}"
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
    -h | --help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      printf 'unknown arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ -t 1 ]]; then
  R='\033[0m'
  B='\033[1m'
  G='\033[32m'
  Y='\033[33m'
  E='\033[31m'
else
  R=''
  B=''
  G=''
  Y=''
  E=''
fi

info() { printf '%bINFO%b %s\n' "$B" "$R" "$*"; }
ok() { printf '%bOK%b   %s\n' "$G$B" "$R" "$*"; }
warn() { printf '%bWARN%b %s\n' "$Y$B" "$R" "$*" >&2; }
err() { printf '%bERR%b  %s\n' "$E$B" "$R" "$*" >&2; }
die() {
  err "$*"
  exit 1
}

case "$MODE" in
  global) TARGET_ROOT="${HOME}/forge" ;;
  project)
    [[ -d "${PROJECT_DIR:-}" ]] || die "project dir missing: $PROJECT_DIR"
    TARGET_ROOT="$(cd -- "$PROJECT_DIR" && pwd)/.forge"
    ;;
esac

[[ -d "$TARGET_ROOT" ]] || die "target does not exist: $TARGET_ROOT"

info "Uninstalling from: $TARGET_ROOT"
info "Dry run: $DRY_RUN"

# Confirm
if ! $FORCE && ! $DRY_RUN; then
  printf '%bConfirm removal?%b (yes/no) ' "$Y$B" "$R"
  read -r reply
  [[ "$reply" == "yes" ]] || die "aborted"
fi

# Backup
BACKUP_DIR="${TARGET_ROOT}/.omf-backup-uninstall-$(date +%Y%m%d-%H%M%S)"
if ! $DRY_RUN; then
  mkdir -p "$BACKUP_DIR"
fi
info "Backup: $BACKUP_DIR"

run() {
  if $DRY_RUN; then
    printf '  [dry-run] %s\n' "$*"
  else
    eval "$*"
  fi
}

remove_item() {
  local item="$1"
  [[ -e "$item" ]] || return 0
  local rel="${item#"$TARGET_ROOT"/}"
  local dest="$BACKUP_DIR/$rel"
  run "mkdir -p \"$(dirname "$dest")\""
  run "mv \"$item\" \"$dest\""
}

MANIFEST="$OMF_DIR/catalog-manifest.json"
if [[ -f "$MANIFEST" ]] && command -v python3 > /dev/null 2>&1; then
  info "Using catalog manifest: $MANIFEST"
  # Read relative paths from the manifest; each path is relative to the repo root.
  # When installed, the file name (basename) is what lives under $TARGET_ROOT.
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    kind="${line%%|*}"
    path="${line##*|}"
    base="$(basename "$path")"
    case "$kind" in
      agent) remove_item "$TARGET_ROOT/agents/$base" ;;
      skill) # For skills, path is like "skills/plan/SKILL.md" — remove the whole dir
        sdir="$(basename "$(dirname "$path")")"
        remove_item "$TARGET_ROOT/skills/$sdir"
        ;;
      command) remove_item "$TARGET_ROOT/commands/$base" ;;
    esac
  done < <(
    python3 - "$MANIFEST" << 'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for kind in ("agents","skills","commands"):
    for entry in m.get(kind, []):
        p = entry.get("path") or ""
        if not p: continue
        print(f"{kind[:-1]}|{p}")
PY
  )
else
  warn "no catalog manifest or python3 — falling back to glob uninstall"
  # Remove all *.md in agents flat
  if [[ -d "$TARGET_ROOT/agents" ]]; then
    while IFS= read -r -d '' f; do
      remove_item "$f"
    done < <(find "$TARGET_ROOT/agents" -maxdepth 1 -type f -name '*.md' -print0)
  fi
  # Remove all skill dirs (containing SKILL.md)
  if [[ -d "$TARGET_ROOT/skills" ]]; then
    for d in "$TARGET_ROOT/skills"/*/; do
      [[ -d "$d" && -f "$d/SKILL.md" ]] || continue
      remove_item "${d%/}"
    done
  fi
  # Remove all *.md in commands flat
  if [[ -d "$TARGET_ROOT/commands" ]]; then
    while IFS= read -r -d '' f; do
      remove_item "$f"
    done < <(find "$TARGET_ROOT/commands" -maxdepth 1 -type f -name '*.md' -print0)
  fi
fi

ok "Uninstall complete"
info "Files moved to: $BACKUP_DIR"
info "To fully remove: rm -rf \"$BACKUP_DIR\""
