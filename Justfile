# ── oh-my-forge Justfile — config lint/fmt gates + omf compiled lanes + TUI ──
# Wires one linter/formatter per config file type AND the omf/ compiled lanes
# (Go dispatcher + Rust core), plus a TUI layer in .just/helpers/ (GNU Bash
# >= 5.3 helpers).
#
# Start here:  bare `just`  → info splash (⏎/m menu · f fzf · countdown)
#              `just menu`  → guided command builder (gum, prompts for params)
#              `just fzf`   → power launcher (fzf, tab multi-select + batch run)
#
#   Markdown (140 files) → rumdl        TOML  → taplo
#   Shell                → shellcheck + shfmt   JSON  → prettier
#   All files            → editorconfig-checker (soft — skipped if missing)
#   omf/dispatch (Go)    → go build/vet/test   omf/core (Rust) → cargo build/clippy/test
#
# Verbs per tool: lint-X (read-only diagnostics) · fmt-X (read-only format
# check) · fix-X (mutating). Umbrellas: lint · fmt · check · fix · omf · ci.
# `ci` is the EXACT CI gate. Never run a destructive fix inside check/ci.

set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false
set positional-arguments := true

helpers := justfile_directory() / ".just" / "helpers"

# Shell sources: repo scripts + the Justfile's own helper layer.
_shell_files := "scripts/*.sh"
_helper_files := ".just/helpers/*.bash"

# JSON file glob — respects .prettierignore.
_json_files := "**/*.json"

# omf compiled lanes (cross-language, owned by separate agents/dirs).
_omf_dispatch := justfile_directory() / "omf" / "dispatch" # Go module
_omf_workspace := justfile_directory() / "omf"             # Cargo workspace (omf-core)

# Parent directory that contains `forge/` (forgecode hardcodes $HOME/forge, so
# install-omf overrides HOME to land at {{ forge_parent }}/forge).
# Override: `just forge_parent=$HOME/.config install-omf` → ~/.config/forge
forge_parent := env_var_or_default("OMF_FORGE_PARENT", env_var("HOME"))

# Timestamped backups of overwritten files — deliberately OUTSIDE the install
# target so the target's VCS (jj, git, fossil, none) never sees backup files.
# Override: `just backup_root=/tmp/omf-backups install-omf`
backup_root := env_var_or_default("OMF_BACKUP_ROOT", env_var("HOME") / ".cache/oh-my-forge/backups")

alias m := menu
alias f := fzf
alias d := doctor
alias b := build
alias t := test
alias l := lint
alias c := check
alias s := search
alias h := help
alias tools := doctor

# ── meta ──────────────────────────────────────────────────────────────────────

# Bare-`just` landing screen: info splash + countdown (never the bare list).
[private]
default:
    @'{{ helpers }}/info-screen.bash'

# Show all recipes with their one-line descriptions.
[group('meta')]
help:
    @just --list --unsorted

# Static info splash (same screen as bare `just`, no countdown).
[group('meta')]
[no-exit-message]
info:
    @'{{ helpers }}/info-screen.bash' --static

# Guided command builder (gum): filter recipes, view source, prompt params.
[group('meta')]
[no-exit-message]
menu:
    @'{{ helpers }}/menu.bash'

# Power launcher (fzf): tab multi-select, batch-run, stop on first failure.
[group('meta')]
[no-exit-message]
fzf:
    @'{{ helpers }}/fzf.bash'

# Dependency audit + project checks. Flags: --summary | --factoid | --install.
[group('meta')]
doctor *args:
    @'{{ helpers }}/doctor.bash' "$@"

# ── trio — multi-agent orchestration (trio-infernale) ──────────────────────────

# Run OUTSIDE tmux. Env knobs: OMF_SESSION, OMF_BOOT_WAIT, OMF_NO_ATTACH.
# Launch the forge+omc+omx orchestra; BOTH workers boot in --madmax (yolo).
[group('trio')]
[no-exit-message]
trio:
    scripts/omf-orchestra.sh

# ── umbrella ──────────────────────────────────────────────────────────────────

# Build every omf compiled lane (Go dispatcher + Rust core).
[group('umbrella')]
build: build-go build-rust
    @printf '\nbuild: OK\n'

# Test every omf compiled lane (Go dispatcher + Rust core).
[group('umbrella')]
test: test-go test-rust
    @printf '\ntest: OK\n'

# Run every linter. Read-only. Fails on the first tool that reports an issue.
[group('umbrella')]
lint: lint-md lint-toml lint-sh lint-json lint-editorconfig
    @printf '\nlint: OK\n'

# Run every formatter check (read-only). Reports which files would change.
[group('umbrella')]
fmt: fmt-md fmt-toml fmt-sh fmt-json
    @printf '\nfmt check: OK\n'

# Full read-only gate: lint + fmt. Suitable for CI and pre-commit hooks.
[group('umbrella')]
check: lint fmt
    @printf '\ncheck: all clean\n'

# Run every auto-fixer. WRITES TO THE FILESYSTEM.
[group('umbrella')]
fix: fix-md fix-toml fix-sh fix-json
    @printf '\nfix: complete — review with `git diff`\n'

# Build, lint, and test every omf compiled lane (Go dispatcher + Rust core).
[group('umbrella')]
omf: build lint-go lint-rust test
    @printf '\nomf: compiled lanes green\n'

# CI entry point: dep audit + config gate + omf compiled lanes (build/lint/test).
[group('umbrella')]
ci: doctor check omf

# ── markdown — rumdl ──────────────────────────────────────────────────────────

# Lint all Markdown files. Config: .rumdl.toml
[group('md')]
lint-md:
    rumdl check .

# Lint Markdown with structured JSON output (LLM format with fix ranges).
[group('md')]
lint-md-json:
    @rumdl check --output-format json .

# Lint Markdown with terse one-line-per-issue output (token-efficient).
[group('md')]
lint-md-concise:
    @rumdl check --output-format concise .

# Show what `rumdl fmt` would change, without writing.
[group('md')]
fmt-md:
    rumdl check --diff .

# Auto-fix every fixable rumdl issue. Writes to the filesystem.
[group('md')]
fix-md:
    rumdl fmt .

# Explain a specific rumdl rule. Usage: just explain-md MD013
[group('md')]
explain-md rule:
    rumdl rule {{ rule }}

# ── toml — taplo ──────────────────────────────────────────────────────────────

# Lint all TOML files (schema + syntax). Config: .taplo.toml
[group('toml')]
lint-toml:
    taplo lint

# Format-check all TOML files (read-only, exits non-zero on drift).
[group('toml')]
fmt-toml:
    taplo format --check --diff

# Auto-format all TOML files. Writes to the filesystem.
[group('toml')]
fix-toml:
    taplo format

# ── shell — shellcheck + shfmt ────────────────────────────────────────────────

# Static-analyze scripts/ and .just/helpers/. Config: .shellcheckrc
[group('shell')]
lint-sh:
    shellcheck {{ _shell_files }}
    shellcheck -x -P .just/helpers {{ _helper_files }}

# Format-check all shell sources (shfmt -d, exits non-zero on drift).
[group('shell')]
fmt-sh:
    shfmt -d -i 2 -ci -bn -sr {{ _shell_files }} {{ _helper_files }}

# Auto-format all shell sources. Writes to the filesystem.
[group('shell')]
fix-sh:
    shfmt -w -i 2 -ci -bn -sr {{ _shell_files }} {{ _helper_files }}

# ── json — prettier ───────────────────────────────────────────────────────────

# Format-check all JSON files. Config: .prettierrc.toml
[group('json')]
lint-json:
    prettier --check {{ _json_files }}

# Alias: format check is the only check prettier does for JSON.
[group('json')]
fmt-json: lint-json

# Auto-format all JSON files. Writes to the filesystem.
[group('json')]
fix-json:
    prettier --write {{ _json_files }}

# ── files — editorconfig ──────────────────────────────────────────────────────

# Verify every file matches .editorconfig rules (soft check — skip if missing).
# Excluded: generated agent-coordination state + virtualenvs (never hand-edited,
# tool-native formatting), and *.go — gofmt owns Go formatting (it understands
# raw-string literals; editorconfig-checker false-positives on spaces inside
# embedded-fixture strings). Go formatting is enforced by `lint-go` via gofmt.
[group('files')]
lint-editorconfig:
    @if command -v editorconfig-checker >/dev/null 2>&1; then \
      editorconfig-checker -exclude '\.beads/|\.omc/|\.omx/|\.venv/|__pycache__/|\.pytest_cache/|^plans/|\.go$'; \
    else \
      printf 'editorconfig-checker not installed — skipping (see `just doctor`)\n' >&2; \
    fi

# ── omf — Go dispatcher (omf/dispatch) ────────────────────────────────────────

# Build the Go dispatcher. Compile-only; no install (use `build-bin` for the binary).
[group('omf')]
build-go:
    cd {{ _omf_dispatch }} && go build ./...

# Emit the actual `omf` dispatcher binary → omf/dispatch/bin/omf.
# `go build ./...` only compile-checks and discards the executable; this writes it.
[group('omf')]
build-bin:
    cd {{ _omf_dispatch }} && go build -o bin/omf ./cmd/omf
    @printf 'built: omf/dispatch/bin/omf\n'

# Vet + gofmt-check the Go dispatcher. gofmt is the authoritative Go formatter
# (it correctly leaves raw-string-literal contents alone, unlike editorconfig).
[group('omf')]
lint-go:
    cd {{ _omf_dispatch }} && go vet ./...
    cd {{ _omf_dispatch }} && out=$(gofmt -l .); [ -z "$out" ] || { printf 'gofmt: needs formatting:\n%s\n' "$out" >&2; exit 1; }

# Test the Go dispatcher (all packages).
[group('omf')]
test-go:
    cd {{ _omf_dispatch }} && go test ./...

# ── omf — Rust core (omf/core, omf-core crate) ────────────────────────────────

# Build the Rust core workspace (debug profile).
[group('omf')]
build-rust:
    cd {{ _omf_workspace }} && cargo build

# Clippy the Rust core — warnings are errors (the omf-core lint gate).
[group('omf')]
lint-rust:
    cd {{ _omf_workspace }} && cargo clippy --all-targets -- -D warnings

# Test the Rust core workspace.
[group('omf')]
test-rust:
    cd {{ _omf_workspace }} && cargo test

# ── install — oh-my-forge into a forge config root ───────────────────────────

# Install oh-my-forge into {{ forge_parent }}/forge with timestamped backups.
[group('install')]
install-omf:
    #!/usr/bin/env bash
    set -euo pipefail
    target="{{ forge_parent }}/forge"
    ts="$(date +%Y%m%d-%H%M%S)"
    backup_dir="{{ backup_root }}/${ts}"
    mkdir -p "{{ backup_root }}"
    mkdir -p "${target}"
    printf 'Installing oh-my-forge\n'
    printf '  source : %s\n' "$(pwd)"
    printf '  target : %s\n' "${target}"
    printf '  backup : %s (only populated if files collide)\n' "${backup_dir}"
    printf '\n'
    HOME="{{ forge_parent }}" ./scripts/install.sh \
      --global \
      --backup-dir "${backup_dir}"
    printf '\n'
    if [[ -d "${backup_dir}" ]]; then
      printf 'Backups of overwritten files saved to:\n  %s\n' "${backup_dir}"
    else
      printf 'No files were overwritten — no backup directory created.\n'
    fi
    printf '\nVerify the install with:  just doctor-omf\n'

# Preview install-omf without touching the filesystem.
[group('install')]
install-omf-dry:
    #!/usr/bin/env bash
    set -euo pipefail
    target="{{ forge_parent }}/forge"
    ts="$(date +%Y%m%d-%H%M%S)"
    backup_dir="{{ backup_root }}/${ts}"
    printf 'Dry-run install of oh-my-forge (no files will be written)\n'
    printf '  target : %s\n' "${target}"
    printf '  backup : %s\n' "${backup_dir}"
    printf '\n'
    HOME="{{ forge_parent }}" ./scripts/install.sh \
      --global \
      --dry-run \
      --backup-dir "${backup_dir}"

# Install the `omf` dispatcher binary to ~/.local/bin (builds it first).
[group('install')]
install-bin: build-bin
    install -d "$HOME/.local/bin"
    install -m 0755 {{ _omf_dispatch }}/bin/omf "$HOME/.local/bin/omf"
    @printf 'installed: %s/.local/bin/omf\n' "$HOME"

# Verify the installed oh-my-forge layout at {{ forge_parent }}/forge.
[group('install')]
doctor-omf:
    HOME="{{ forge_parent }}" ./scripts/doctor.sh --global

# Run the repo's own doctor script (this checkout, not the installed target).
[group('install')]
doctor-repo:
    ./scripts/doctor.sh --repo

# ── clean ─────────────────────────────────────────────────────────────────────

# Clean rumdl's on-disk cache.
[group('clean')]
clean:
    rumdl clean
    @printf 'clean: rumdl cache cleared\n'

# ── util ──────────────────────────────────────────────────────────────────────

# Live ripgrep search → fzf → open the hit in $EDITOR. Usage: just search [query]
[group('util')]
[no-exit-message]
search *query:
    @'{{ helpers }}/search.bash' "$@"

# Pick a file with fzf (bat preview) and open it in $EDITOR.
[group('util')]
[no-exit-message]
pick:
    @'{{ helpers }}/pick.bash' file

# Switch git branch interactively.
[group('util')]
[no-exit-message]
branch:
    @'{{ helpers }}/pick.bash' branch
