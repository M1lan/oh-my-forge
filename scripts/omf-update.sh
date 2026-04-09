#!/usr/bin/env bash
# oh-my-forge update script
#
# Pulls the latest oh-my-forge from its git remote (if this is a clone),
# then re-runs the installer to refresh the installed components.
# Never modifies files outside $HOME/forge unless --project is passed.
#
# Usage:
#   ./scripts/omf-update.sh [--global | --project DIR] [--skip-pull]

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMF_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MODE_ARGS=("--global")
SKIP_PULL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      MODE_ARGS=("--global")
      shift
      ;;
    --project)
      MODE_ARGS=("--project" "${2:-.}")
      shift 2
      ;;
    --skip-pull)
      SKIP_PULL=true
      shift
      ;;
    -h | --help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      printf 'unknown arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ! $SKIP_PULL; then
  if git -C "$OMF_DIR" rev-parse > /dev/null 2>&1; then
    printf 'pulling latest oh-my-forge...\n'
    git -C "$OMF_DIR" pull --ff-only || {
      printf 'git pull failed — continuing with local checkout\n' >&2
    }
  else
    printf 'not a git checkout — skipping pull\n'
  fi
fi

exec "$SCRIPT_DIR/install.sh" "${MODE_ARGS[@]}" --force
