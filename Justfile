# ==============================================================================
# Justfile — oh-my-forge task runner
# ==============================================================================
# Run `just` (or `just help`) for the list of available recipes.
#
# This repo is a configuration-only pack: no source code, no build step, no
# test suite. The Justfile wires up linters and formatters for every file
# type found in the tree:
#
#   Markdown  (110 files) → rumdl        (fast Rust markdownlint)
#   TOML      (1 file)    → taplo        (TOML toolkit: fmt + lint + LSP)
#   Shell     (5 files)   → shellcheck + shfmt
#   JSON      (2 files)   → prettier     (JSON only — not prose)
#   All files             → editorconfig-checker (if installed)
#
# Three verbs apply to each tool:
#
#   lint-X    Read-only diagnostic pass. Exits non-zero on any issue.
#   fmt-X     Format check (read-only). Exits non-zero if any file would change.
#   fix-X     Mutating fix pass. Writes to the filesystem.
#
# Aggregate recipes:
#
#   lint      Run every linter. Read-only. CI default.
#   fmt       Run every formatter check. Read-only.
#   check     lint + fmt (full read-only gate).
#   fix       Run every auto-fixer. Writes to the filesystem.
#   ci        check + tools (CI entry point).
#   tools     Print which tools are installed and which are missing.
#   install   Print install instructions for each tool.
#
# Philosophy: one tool per filetype, fail loudly, never run a destructive
# fix inside the `check` or `ci` path.
# ==============================================================================

# Use bash with strict mode for every recipe.
set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false
set positional-arguments := true

# Default recipe: show the help screen.
default: help

# ------------------------------------------------------------------------------
# Meta
# ------------------------------------------------------------------------------

# Show all recipes with their one-line descriptions.
help:
    @just --list --unsorted

# Print which linters/formatters are installed and which are missing.
tools:
    #!/usr/bin/env bash
    set -uo pipefail
    printf '%-22s %-10s %s\n' "TOOL" "STATUS" "VERSION"
    printf '%-22s %-10s %s\n' "----" "------" "-------"
    check() {
      local name=$1 cmd=$2
      if command -v "$cmd" >/dev/null 2>&1; then
        local ver
        ver=$("$cmd" --version 2>&1 | head -1 | tr -d '\r')
        printf '%-22s %-10s %s\n' "$name" "OK" "$ver"
      else
        printf '%-22s %-10s %s\n' "$name" "MISSING" "-- install via 'just install'"
      fi
    }
    check rumdl rumdl
    check taplo taplo
    check shellcheck shellcheck
    check shfmt shfmt
    check prettier prettier
    check editorconfig-checker editorconfig-checker

# Print install instructions for every tool this Justfile uses.
install:
    @echo "oh-my-forge uses the following tools. Install the ones marked MISSING"
    @echo "by 'just tools'."
    @echo ""
    @echo "  rumdl       cargo install rumdl  |  brew install rumdl"
    @echo "  taplo       cargo install taplo-cli --locked  |  brew install taplo"
    @echo "  shellcheck  brew install shellcheck  |  apt install shellcheck"
    @echo "  shfmt       brew install shfmt  |  go install mvdan.cc/sh/v3/cmd/shfmt@latest"
    @echo "  prettier    npm i -g prettier  |  brew install prettier"
    @echo "  editorconfig-checker  brew install editorconfig-checker  (optional)"
    @echo ""
    @echo "On macOS, a single brew one-liner installs everything:"
    @echo "  brew install rumdl taplo shellcheck shfmt prettier editorconfig-checker"

# ------------------------------------------------------------------------------
# Markdown — rumdl
# ------------------------------------------------------------------------------

# Lint all Markdown files. Config: .rumdl.toml
lint-md:
    rumdl check .

# Lint Markdown with structured JSON output (LLM format with fix ranges, jq-safe).
lint-md-json:
    @rumdl check --output-format json .

# Lint Markdown with terse one-line-per-issue output (token-efficient).
lint-md-concise:
    @rumdl check --output-format concise .

# Show what `rumdl fmt` would change, without writing.
fmt-md:
    rumdl check --diff .

# Auto-fix every rumdl issue that is fixable. Writes to the filesystem.
fix-md:
    rumdl fmt .

# Explain a specific rumdl rule. Usage: just explain-md MD013
explain-md rule:
    rumdl rule {{ rule }}

# ------------------------------------------------------------------------------
# TOML — taplo
# ------------------------------------------------------------------------------

# Lint all TOML files (schema + syntax). Config: .taplo.toml
lint-toml:
    taplo lint

# Format-check all TOML files (read-only, exits non-zero on drift).
fmt-toml:
    taplo format --check --diff

# Auto-format all TOML files. Writes to the filesystem.
fix-toml:
    taplo format

# ------------------------------------------------------------------------------
# Shell — shellcheck (lint) + shfmt (format)
# ------------------------------------------------------------------------------

# Shell file glob used by every shell recipe below.
_shell_files := "scripts/*.sh"

# Static-analyze all shell scripts. Config: .shellcheckrc
lint-sh:
    shellcheck {{ _shell_files }}

# Format-check all shell scripts (shfmt -d, exits non-zero on drift).
fmt-sh:
    shfmt -d -i 2 -ci -bn -sr {{ _shell_files }}

# Auto-format all shell scripts. Writes to the filesystem.
fix-sh:
    shfmt -w -i 2 -ci -bn -sr {{ _shell_files }}

# ------------------------------------------------------------------------------
# JSON — prettier
# ------------------------------------------------------------------------------

# JSON file glob — respects .prettierignore.
_json_files := "**/*.json"

# Format-check all JSON files. Config: .prettierrc.toml
lint-json:
    prettier --check {{ _json_files }}

# Alias: format check is the only check prettier does for JSON.
fmt-json: lint-json

# Auto-format all JSON files. Writes to the filesystem.
fix-json:
    prettier --write {{ _json_files }}

# ------------------------------------------------------------------------------
# EditorConfig — verify indent / charset / line-ending compliance
# ------------------------------------------------------------------------------
# This is a soft check: if editorconfig-checker is not installed, skip silently.

# Verify every file matches .editorconfig rules.
lint-editorconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v editorconfig-checker >/dev/null 2>&1; then
      editorconfig-checker
    else
      echo "editorconfig-checker not installed — skipping (run 'just install' for instructions)"
    fi

# ------------------------------------------------------------------------------
# Aggregate recipes
# ------------------------------------------------------------------------------

# Run every linter. Read-only. Fails on the first tool that reports an issue.
lint: lint-md lint-toml lint-sh lint-json lint-editorconfig
    @echo ""
    @echo "lint: OK"

# Run every formatter check (read-only). Reports which files would change.
fmt: fmt-md fmt-toml fmt-sh fmt-json
    @echo ""
    @echo "fmt check: OK"

# Full read-only gate: lint + fmt. Suitable for CI and pre-commit hooks.
check: lint fmt
    @echo ""
    @echo "check: all clean"

# Run every auto-fixer. WRITES TO THE FILESYSTEM.
fix: fix-md fix-toml fix-sh fix-json
    @echo ""
    @echo "fix: complete — review with 'git diff'"

# CI entry point: verify tools are installed, then run the full read-only gate.
ci: tools check

# ------------------------------------------------------------------------------
# Repo-specific housekeeping
# ------------------------------------------------------------------------------

# Run the repo's doctor script (verifies oh-my-forge installation layout).
doctor:
    ./scripts/doctor.sh --repo

# Clean rumdl's on-disk cache.
clean:
    rumdl clean
    @echo "clean: rumdl cache cleared"
