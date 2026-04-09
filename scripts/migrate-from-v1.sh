#!/usr/bin/env bash
# oh-my-forge: migrate from v1 to v2
#
# v1 used forge.yaml. v2 uses .forge.toml and refuses to parse forge.yaml.
# This script detects v1 projects and helps migrate them.
#
# Usage:
#   ./scripts/migrate-from-v1.sh [DIR]
# Default DIR is ".".

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMF_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DIR="${1:-.}"
[[ -d "$DIR" ]] || { printf 'dir missing: %s\n' "$DIR" >&2; exit 1; }
DIR="$(cd -- "$DIR" && pwd)"

if [[ -t 1 ]]; then
  R='\033[0m'; B='\033[1m'; G='\033[32m'; Y='\033[33m'; E='\033[31m'
else
  R=''; B=''; G=''; Y=''; E=''
fi

info() { printf '%bINFO%b %s\n' "$B" "$R" "$*"; }
ok()   { printf '%bOK%b   %s\n' "$G$B" "$R" "$*"; }
warn() { printf '%bWARN%b %s\n' "$Y$B" "$R" "$*" >&2; }
err()  { printf '%bERR%b  %s\n' "$E$B" "$R" "$*" >&2; }

info "Checking $DIR for v1 oh-my-forge artefacts"

FOUND=0

if [[ -f "$DIR/forge.yaml" ]]; then
  warn "found legacy forge.yaml — this is a v1 artefact and is obsolete"
  FOUND=1
  BAK="$DIR/forge.yaml.v1.bak"
  cp "$DIR/forge.yaml" "$BAK"
  info "backed up to $BAK"
  rm "$DIR/forge.yaml"
  ok "removed forge.yaml"
fi

# Check for nested agent subdirs
if [[ -d "$DIR/.forge/agents" ]]; then
  nested=0
  while IFS= read -r -d '' _sub; do
    nested=$((nested + 1))
  done < <(find "$DIR/.forge/agents" -mindepth 1 -type d -print0 2>/dev/null)
  if [[ $nested -gt 0 ]]; then
    warn "found $nested subdirectories under .forge/agents/ — v1 layout is obsolete"
    warn "forgecode does NOT recurse into subdirectories for agents"
    FOUND=1
    printf 'Flatten automatically? (yes/no) '
    read -r reply
    if [[ "$reply" == "yes" ]]; then
      BACKUP="$DIR/.forge/agents.v1.bak"
      mkdir -p "$BACKUP"
      cp -a "$DIR/.forge/agents/." "$BACKUP/"
      info "backup: $BACKUP"
      while IFS= read -r -d '' f; do
        base="$(basename "$f")"
        target="$DIR/.forge/agents/$base"
        if [[ -e "$target" && "$f" != "$target" ]]; then
          warn "collision: $base exists at top level; skipping $f"
        else
          mv "$f" "$target"
        fi
      done < <(find "$DIR/.forge/agents" -mindepth 2 -type f -name '*.md' -print0)
      # Remove empty directories
      find "$DIR/.forge/agents" -mindepth 1 -type d -empty -delete
      ok "flattened .forge/agents/"
    else
      warn "not flattened; your agents will NOT load until you flatten them"
    fi
  fi
fi

# Check for .mcp.json in a subdirectory (v1 may have put it anywhere)
if [[ -f "$DIR/.forge/.mcp.json" ]]; then
  warn "found .forge/.mcp.json — forgecode looks for .mcp.json at the cwd root, not inside .forge"
  FOUND=1
  info "move it:  mv $DIR/.forge/.mcp.json $DIR/.mcp.json"
fi

# Check for ~/forge/.forge.toml vs project .forge.toml — inform user
if [[ -f "$DIR/.forge.toml" ]]; then
  ok "$DIR/.forge.toml already present"
elif [[ -f "$HOME/forge/.forge.toml" ]]; then
  info "global $HOME/forge/.forge.toml present — it will apply"
else
  warn "no .forge.toml found. Copy the example:"
  warn "  cp $OMF_DIR/.forge.toml $DIR/.forge.toml"
fi

if [[ $FOUND -eq 0 ]]; then
  ok "no v1 artefacts detected"
else
  ok "migration complete — review changes and run scripts/doctor.sh"
fi
