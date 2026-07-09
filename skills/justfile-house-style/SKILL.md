---
name: justfile-house-style
description: Canonical house style for creating/editing Justfiles — thin Justfile + .just/helpers/ architecture, GNU Bash >= 5.3 or Python >= 3.14.5 helpers ONLY, tput default colors (themes abolished), self-updating gum menu, doctor, info splash. Load whenever a Justfile is created, edited, reviewed, or discussed.
triggers:
  - Justfile
  - justfile
  - .just/helpers
  - just recipe
  - just menu
  - task runner setup
---

# Justfile House Style (v3 — current default)

Authoritative workflow for creating Justfiles in any project. "Justfile" **always
implies "Bash 5.3 Programming"**: the `write-bash` skill applies in full to every
recipe body and every helper script. Memory sources: mempalace wing
`justfile_patterns` (rooms `tui_design_v3`, `gotchas`, `general`), cortex
observations on gum/SIGINT and the 2026-06-07 house-style hard rules.

## Iron Rules (non-negotiable)

1. **Helper/scripting languages — exactly two are permitted:**
   - **GNU Bash >= 5.3** (operator minimum: 5.3.12). ONLY GNU Bash — no BSD sh,
     no zsh, no macOS `/bin/bash` 3.2. "Bash 5" alone is WRONG: 5.3 added
     language features the helpers rely on. Guard must check the **minor** version:

     ```bash
     ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3))) || {
         printf 'error: GNU Bash >= 5.3 required, got %s\n' "$BASH_VERSION" >&2
         printf 'hint : brew install bash  (/opt/homebrew/bin must precede /bin in PATH)\n' >&2
         exit 1
     }
     ```

     NEVER the weak `(( BASH_VERSINFO[0] >= 5 ))` — it accepts 5.0–5.2.
   - **Python >= 3.14.5, stdlib only** — for the rare *justified* case bash
     genuinely can't do (e.g. real XML parsing of a JaCoCo report). Guard:

     ```python
     import sys
     if sys.version_info < (3, 14, 5):
         sys.exit("error: Python >= 3.14.5 required, got "
                  + ".".join(map(str, sys.version_info[:3])))
     ```

     No third-party imports, no venv, no uv-managed deps in `.just/helpers/`.
   - Nothing else. No node, no perl, no ruby helpers.

2. **Themes are ABOLISHED.** No `THEME` parameters, no `theme-light`/`theme-dark`
   virtual entries, no hex brand palettes, no background painting, no
   `GUM_*_BACKGROUND` exports. Colors come from the **terminal's default palette
   via tput** (see Colors section). The user's terminal scheme is the single
   source of color truth.

3. **No separator/header entries in fzf/gum selectors.** Separator lines ARE
   selectable; picking one is a broken no-op. Grouping is a `[group]` COLUMN on
   every real item: `printf '%-18s %-10s %s' "$name" "[$group]" "$doc"`.
   Virtual entries like `quit` are fine — they are real actions.

4. **Tooling:** `rg` never grep, `fd` never find, GNU/Homebrew tools never BSD,
   `gawk`/`gdate` g-prefixed on macOS.

5. **NEVER clear the user's screen or destroy scrollback (operator rule,
   2026-06-15, ABSOLUTE).** No `clear`, no `tput clear`, no `tput ed`/`tput E3`,
   no `printf '\033[2J'`/`\033[3J`, in ANY recipe, helper, splash, menu, or
   bootstrap — past, present, or future. Clearing adds nothing and ENRAGES the
   user because it wipes their terminal scrollback (they lose the output they
   were reading). The bare-`just` info splash, the gum menu loop, the doctor
   table — all must PRINT INLINE and append to the scrollback, never wipe it.
   - A live in-place repaint (the bootstrap install splash) is the ONLY case
     that needs in-place redraw. Do it with the ALTERNATE SCREEN BUFFER
     (`tput smcup` on entry, `tput rmcup` on EVERY exit path incl. traps) plus
     `tput cup 0 0` to home the cursor between frames — exactly like
     less/fzf/vim. The alternate screen is a separate buffer that fully RESTORES
     the primary screen and scrollback on exit; it is not "clearing". fzf's own
     alt-screen (default) is fine for the same reason.
   - `tput el` (erase the CURRENT line only) for a `\r` status/countdown line is
     allowed — it touches one line, never scrollback.
   - This rule outranks any prettiness concern. When in doubt, append.

## Architecture: thin Justfile + `.just/helpers/`

The Justfile contains **no large bash blobs**. TUI/logic lives in
`.just/helpers/` (committed to git, executable). Recipes are one-liners:

```just
helpers := justfile_directory() / ".just" / "helpers"

[group('meta')]
[no-exit-message]
menu:
    @'{{helpers}}/menu.bash'
```

Standard helper set (adapt per project):

| helper | purpose |
|---|---|
| `lib.bash` | sourced library: tput default colors, `has`/`die`/`is_tty`, fast project facts |
| `info-screen.bash` | bare-`just` splash + countdown (keys: ⏎/m menu · f fzf · other shell) |
| `menu.bash` | the GUM launcher (gum-only, **never invokes fzf**): guided command builder |
| `fzf.bash` | the FZF launcher (fzf-only, **never invokes gum**): flat power surface |
| `doctor.bash` | dep audit (required/recommended/optional tiers + project checks) + install TUI + `--factoid` |
| `search.bash` | live rg → fzf (reload-on-keystroke) → bat → `$EDITOR` |
| `pick.bash` | fzf pickers: file / branch / project-specific artifacts |
| `bootstrap.bash` | `make` lands here: bg installer + live install splash + one-time welcome |

**Bootstrap pattern (operator, 2026-06-08):** a codegolf Makefile
(`.POSIX:` + `all: ; @.just/helpers/bootstrap.bash`) is the zero-to-ready
entry. `bootstrap.bash` spawns itself (`--install`) in the background logging
to `.just/state/bootstrap.log` (state dir gitignored), with sidecar files
`bootstrap.steps` (`name|state|detail` per step), `bootstrap.stats`
(key=value), `bootstrap.status` (running/ok/fail). Foreground: 2 Hz loading
splash whose DOMINANT panel is the tinted live log tail (thick yellow border;
label + `─` separator as first lines inside the box), side rail = identity +
spinner checklist (`⠋⠙⠹…`, ✓/✗) + dim hotkey strip, NO timeout until the
installer finishes. Hotkeys: q abort (kill installer) · s shell-now (installer
continues) · l `less +F` the log. UI tools (just, gum, jq, fzf, bat) install
FIRST so the splash upgrades itself mid-run; non-hotkey keys are swallowed.
Success → one-time ASCII-art welcome (stats from `bootstrap.stats` + WHAT-NEXT
in the screen's only thick yellow box + 4.2 s tenths countdown,
`JUST_WELCOME_SECS` override, `--welcome` flag re-renders for preview/QA).
Failure → red summary + log tail + exit 1. `just bootstrap` = parity recipe.

**Helper contract** (every executable helper): `#!/usr/bin/env bash`, executable
bit set, sources `lib.bash` via
`source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"` with a
`# shellcheck source=lib.bash` directive, `cd "$REPO_ROOT" || exit 1`,
`trap 'exit 130' INT TERM HUP`, dependency check loop
(`has gum || die "..."`).

**set-flag discipline (deliberate, not an omission):** TUI helpers MUST NOT use
`set -e` — it defeats the mandated rc-capture pattern
(`rc=0; choice=$(gum filter ...) || rc=$?` dies before the rc check under `-e`).
`lib.bash` carries `set -o pipefail`; helpers inherit it by sourcing and use
explicit per-command checks instead — the write-bash "complex script"
convention. `-u` is fine if every possibly-empty array uses the
`"${arr[@]+"${arr[@]}"}"` guard.

`lib.bash` itself: SOURCED, never executed — **no shebang**; opens with
`# shellcheck shell=bash disable=SC2034` (sourced files trip SC2148 without
`shell=`, and its exported vars look "unused" → SC2034). It carries the Bash
5.3 guard so every helper inherits it, and marks repo facts
`readonly LIB_DIR REPO_ROOT`.

## Justfile preamble (non-negotiable)

```just
set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false
set positional-arguments := true

helpers := justfile_directory() / ".just" / "helpers"
```

- Header comment block: project name, build system, where helpers live, "start
  here: bare `just`".
- Variables before recipes; runtime-overridable knobs via
  `env_var_or_default("NAME", "default")` (e.g. variant axes:
  `bom := env_var_or_default("BOM", "9999.0.0-LOCAL")` →
  `BOM=276 just test` works).
- Aliases block for muscle memory: `alias m := menu`, `alias t := test`, …
- Exports: `export GRADLE_OPTS := env_var_or_default(...)` etc.

## Recipes

- **`[group('name')]` on every recipe.** Group names <= 8 chars **so `[group]`
  fits the `%-10s` menu column** (widen both together if you ever need longer)
  — from: `umbrella build run test lint verify docs clean git util meta` plus
  project-specific ones (`evidence`, `site`, `libs`, `bench`, `gitlab`).
  Canonical section order: umbrella, meta, (domain groups), build, run, test,
  lint, clean, git, util — each under a `# ── section ──` banner comment.
- **Doc comment = ONE line directly above the recipe header.** Multi-line `#`
  stacks silently lose every line except the last in `just --list`.
- `default` recipe is `[private]` and runs `@'{{helpers}}/info-screen.bash'`.
- `help` runs `@just --list --unsorted`.
- **`menu` and `fzf` are TWO SEPARATE recipes/TUIs (operator rule, 2026-06-08;
  supersedes the old `fzf: menu` compat dependency).** `menu` → `menu.bash`
  (gum-only) and `fzf` → `fzf.bash` (fzf-only). They must offer deliberately
  DIFFERENT UX, not the same list twice — see "Dual-TUI identities" below.
  Aliases `alias m := menu`, `alias f := fzf` for muscle memory.
- Umbrella meta-recipes bundle families **via dependencies, not shell `&&`**:
  `ci` (the EXACT CI gate), `qa`, `all`, `fresh`.
- `[no-exit-message]` on every interactive/TUI recipe.
- Optional tools guarded:
  `@if command -v rumdl >/dev/null 2>&1; then ...; else printf '... -- skipping\n' >&2; fi`.
- `rm -f` / `rm -rf` for cleanups so missing files don't fail.
- Parametrized recipes: `test-filter filter:` …; defaults `probe path='/text':`;
  passthrough `run *args`.
- Build menus with `printf '%s\n'` — **never heredocs** (just parses `---` as
  tokens inside recipe bodies).
- JVM projects: never spawn Gradle/JVM on the splash/menu path — file-parse
  facts instead (gradle-wrapper.properties, build.gradle.kts, report XML).

## Colors: terminal defaults via tput ONLY

```bash
_ncolors=0
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    _ncolors=$(tput colors 2>/dev/null || printf 0)
fi
if (( _ncolors >= 8 )); then
    C_RESET=$(tput sgr0)  C_BOLD=$(tput bold)  C_DIM=$(tput dim)
    C_RED=$(tput setaf 1) C_GREEN=$(tput setaf 2) C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4) C_MAGENTA=$(tput setaf 5) C_CYAN=$(tput setaf 6)
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi
```

- ANSI indexes 0–7 only — they map to the user's terminal scheme.
- **tput consults only `$TERM`, not isatty()** — guard every call site on the
  tty check above or piped output gets polluted with escapes.
- `tput dim`/`bold` can be empty on some `$TERM`s — always assign via
  command substitution (empty is harmless), never assume they render.
- Honor `NO_COLOR` and non-tty (CI logs stay clean). Never raw `\033[` escapes.
- gum: rely on its defaults; accents via ANSI index strings
  (`--border-foreground "6"`); never paint backgrounds.
- bat: default theme or `--theme=ansi`.
- figlet banner gradient: cycle ANSI indexes (`BANNER_RAMP=(6 4 2 ...)`), never
  truecolor ramps.

## TUI patterns

**Dual-TUI identities (menu = gum, fzf = fzf — never mix, never converge):**

- **`just menu` (gum-only)** — the guided *command builder*: gum filter over the
  grouped list; selecting a parametrized recipe shows its source (bat,
  `--language=make`) and prompts each param via `gum input` (defaults/variadics
  skippable on empty), then `gum confirm` → `exec just …`; loops back after
  cancel. For someone who does NOT know the recipe name.
- **`just fzf` (fzf-only)** — the flat *power launcher*: every recipe in one
  dense alt-screen pane, always-on `just --show {1}` preview, **`--multi`**:
  Tab-select N recipes → batch runs in list order, stopping at first failure.
  No param prompting — bare exec, `just`'s own usage error is the feedback.
  Bindings: `ctrl-r` reload (`"$0" --rows` re-entrant), `ctrl-/` toggle preview.
- The convergence test: **menu PROMPTS for params; fzf MULTI-SELECTS.** If both
  do neither, they have converged and one must be re-differentiated.
- **Polish vocabulary (designer spec, 2026-06-08, "Swiss terminal minimalism"):**
  one accent (cyan 6), one warning (yellow 3), green 2 = success only, red 1 =
  destructive only. fzf: `--style=full` + `--color
  'border:6,label:6,header:3,prompt:6,pointer:6,marker:2,spinner:6,info:8,separator:8,scrollbar:8'
  + 'hl:6,hl+:6,fg+:-1,bg+:-1'` (NO bg wash on selection — the `▌` pointer
  carries it), `--prompt '  ❯ '`, labels on border/list/input/preview,
  `tab:toggle+down`/`shift-tab:toggle+up`. Semantic group palette in the
  `[group]` column: green verify/build · cyan run · yellow test · magenta
  lint/sec · blue docker · red clean · dim util/meta. gum menu: rounded 2-line
  header (bold-cyan name / dim subtitle), filter
  `--indicator.foreground 6 --match.foreground 6 --header.foreground 3
  --prompt '  › ' --prompt.foreground 6`, input `--prompt '  ❯ '` + cyan
  cursor, confirm `--prompt.foreground 6`. Hi-viz hotkey box: thick yellow
  border vs rounded cyan everywhere else — that ONE contrast is the grammar.

**Self-updating menu** — items generated at runtime so the menu never goes stale:

```bash
just --dump --dump-format json | jq -r '
    .recipes | to_entries[]
    | select(.key | startswith("_") | not)
    | select(.key != "default")
    | select([.value.attributes[]? | strings] | index("private") | not)
    | [ .key,
        (([.value.attributes[]? | objects | .group] | first) // "misc"),
        (.value.doc // ""),
        ([.value.parameters[]?
          | .name + (if .kind == "star" or .kind == "plus" then "*"
                     elif .default != null then "?"
                     else "" end)] | join(" "))
      ] | @tsv'
```

Param suffixes: `?` = has default (skippable), `*` = variadic (`kind`
star/plus, `default` is null — checking default alone mis-prompts variadics
as required). Variadic input is word-split into separate args.

Attributes are a MIXED array (strings + `{"group": ...}` objects) — jq must
split with `strings`/`objects` or `index()` explodes. Order groups via a
`GROUP_ORDER` bash array; unknown groups sort last. Defaulted params get a `?`
suffix; prompt each via `gum input`, empty answer on a defaulted param `break`s
so just fills the rest. Preview:
`just --show <r> | bat --language=make ... || just --show <r>` (keep the plain
fallback). **bat has NO just grammar** — an unknown `-l` silently degrades to
uncolored plain output (no error); `--language=make` is used because Justfile
bodies are make-like and it gives real highlighting. Confirm via
`gum confirm` → `exec just <name> "${args[@]+"${args[@]}"}"`.

**gum filter call** (the menu IS a gum filter — full list visible, narrows live):

```bash
height=$(( $(term_lines) - 12 )); (( height < 8 )) && height=8   # floor!
printf '\n'   # at every loop-top render: append a spacer, NEVER `clear`
              # (Iron Rule 5) — gum filter redraws its own region inline
gum filter --no-fuzzy --reverse --height="$height" \
    --placeholder='type a recipe…' --header="$header" --indicator='▌'
```

`--no-fuzzy` = word-prefix matching (`te` hits `test`, not `pretest`).

**SIGINT safety**: `trap 'exit 130' INT TERM HUP` + rc-capture
(`rc=0; choice=$(gum filter ...) || rc=$?`) — **never `|| true` around gum**:
`|| true` + `while true` = unkillable Ctrl-C loop (130 → 0 → loop iterates).
Distinguish cancel(130)/no-match(1)/ok(0) via the captured rc.

**Info splash** (bare `just`): figlet banner (smslant → slant → default
fallback) + plain-text panel functions boxed by
`gum style --border rounded --width W` and composed with
`gum join --horizontal --align top` (gum does ANSI-aware width math — never
hand-roll visible-width columns in bash). Layout by width: >=130 three columns,
>=96 two, else stacked. **Degradation chain (operator rule, 2026-06-08 —
supersedes the old `exec just --list` fallback): bare `just` ALWAYS shows the
info splash.** Non-tty OR cols<78 OR lines<24 OR no gum → degrade to the
`--static` render (same screen, no countdown) — NEVER to the bare list (that
lives on `just help`). `stty size` reports `0 0` on degenerate ptys (Emacs
shell, fresh pty wrappers) — `_term_size` must reject non-positive values
and floor at 80x24.
Countdown (default 5s, `JUST_SPLASH_SECS` override): highly visible footer with
reverse-video digit; `read -rsn1 -t 1` with **rc-capture** (`rc=0; read … || rc=$?`;
rc>128 = timeout → next tick, rc=1 = EOF → stop). Key dispatch: ⏎/m →
`exec just menu`, f → `exec just fzf`, ANY other key (q, Esc, arrows) → shell
NOW. Timeout → print ONE frugal factoid (`doctor.bash --factoid`) + exit 0.
`tput civis` during countdown ⇒ a `restore() { tput cnorm; }` called on every
exit path **explicitly before `exec`** (exec skips EXIT traps) and in the
INT/TERM/HUP trap. Factoid priority: missing required deps > missing optional >
no test report > no dist > dirty tree > all-green tip; format
`<problem> -- <the one fixing command>`, no prose.

**doctor**: three tiers (`REQUIRED`/`RECOMMENDED`/`OPTIONAL` arrays) + assoc
arrays `PKG` (tool→brew formula where names differ: rg→ripgrep,
gdate→coreutils) and `WHY` (one-line purpose). Project checks beyond CLI tools
(wrapper present, auth env vars set, sibling checkouts, artifacts published).
`--summary` one-liner for the splash; `--factoid` = the single most important
fact for the splash-timeout exit line; `--install` = gum choose --no-limit
multi-select of missing (real items only, no headers) → `gum spin -- brew
install`. **Exit non-zero when required deps missing** ⇒ CI-runnable. The bash
row check uses the full major+minor guard.

**Live rg search**: `fzf --ansi --disabled --query "$q"` +
`--bind "change:reload:sleep 0.05; $RG -- {q} || true"` + ctrl-f transform
toggling rg-live ↔ fuzzy-on-frozen; bat preview `--highlight-line {2}`
centered via `--preview-window '...,+{2}+3/2,~3'`; Enter →
`exec "${EDITOR:-nano}" "+$line" "$file"`.

## Gotchas checklist (each has bitten before)

1. Separator entries in selectors are selectable → `[group]` column instead.
2. tput colorizes piped output (`$TERM`-only) → tty-guard every call site.
3. `just --dump` attributes = mixed strings/objects → jq `strings`/`objects`.
4. bat has no `just` grammar (only Makefile) → `--language=make`; unknown `-l`
   silently falls back to PLAIN (no error, but no color either).
5. Heredocs in recipe bodies break (`---` token) → `printf '%s\n'`.
6. Multi-line doc comments: only the last line reaches `just --list`.
7. `|| true` around gum + loop = unkillable Ctrl-C → trap + rc-capture.
8. Shipping `.py` helpers → add `__pycache__/` to .gitignore.
9. Hand-rolled column math breaks on ANSI → `gum style --width` + `gum join`.
10. Empty-array expansion under `set -u` → `"${arr[@]+"${arr[@]}"}"`.
11. `git add <dir>` works normally with native git (no wrapper-specific
    staging quirks remain).
12. JVM spawn on splash path (1s+) → file-parse facts only.
13. `$(tput cols)` inside command substitution sees a PIPE, not the tty →
    silently reports 80 and the splash picks the wrong layout. Use
    `stty size </dev/tty` (gstty if present); precedence: COLUMNS/LINES env
    (test override) > stty on /dev/tty > tput > 80x24.
14. fzf `--preview-window '<N(alt)'` compares N against the PREVIEW WINDOW's
    width, not the terminal's. `right,55%,<96(down)` on a 140-col terminal
    gives 77 < 96 → down layout. Pick the threshold for the pane (e.g. `<70`).
15. gum 0.17 `filter`: first Esc only leaves typing mode (keys become j/k
    navigation!); Esc-Esc or Ctrl-C quits. Say "esc esc quits" in headers, and
    never assume one Esc ended the process when driving it from tmux/scripts.
16. Variadic params (`kind: "star"`) have `default: null` → a default-only jq
    check labels them required. Suffix `*`, prompt skippable, word-split input.
17. fzf fuzzy match includes the DOC column — a query like `loc` can select
    `clean-all` (matches "…local caches") and Tab-batch it. Destructive-ish
    recipes get matched by surprising queries; this is accepted power-user
    behavior, but keep batch runs stop-on-first-failure and echo each command.
18. `tput rev`/`tput el`/`tput cup`/`tput smcup` are `$TERM`-only like setaf
    (gotcha #2 in full generality) — EVERY cursor/screen op leaks escapes into
    pipes. `C_REV` lives in lib.bash behind the tty/color gate; `tput el`/`cup`/
    `smcup`/`rmcup` call sites get `is_tty &&`. (`clear` itself is BANNED by Iron
    Rule 5 — never reintroduce it as a "call site".)
19. Redirection order: `cmd </dev/tty 2>/dev/null` still prints
    "/dev/tty: Device not configured" — redirections apply LEFT-TO-RIGHT, so
    stderr must be silenced BEFORE the failing open: `cmd 2>/dev/null </dev/tty`.
    (macOS `[[ -r /dev/tty ]]` passes even without a controlling tty.)
20. `read -rsn1 -t N` with stdin at EOF (rc=1) returns INSTANTLY — a render
    loop spins hot. Pace by hand: `(( rc == 1 )) && sleep 0.5`.
21. gum filter has NO `--ansi` render flag (only `--strip-ansi` for input) —
    group-column ANSI tinting works in fzf (`--ansi`, which also strips codes
    from the OUTPUT so name extraction stays safe) but NOT in gum menus.
22. A left hotkey rail (16 cols) + three 40-col content panels needs >=144
    cols; at 130–143 use 3 columns + bottom hotkey bar instead — compute, don't
    eyeball, gum box widths (`(COLS - rail - margins) / 3` vs content width).
23. gum/lipgloss QUERIES the terminal (DSR `ESC[6n`, OSC 11 bg) when its
    stdout is the tty; the terminal's REPLIES land in the SCRIPT's stdin and
    the next `read -rsn1` eats the reply's ESC → "any key → shell" fires →
    the countdown exits instantly. Invisible in mute test ptys (nothing
    replies) — only real terminals reproduce it. Fix: `drain_tty_input`
    (burst-drain stdin until quiet ~100ms) in lib.bash, called after the gum
    render, before EVERY hotkey read loop. Test harnesses must emulate a
    REPLYING terminal to cover this.
24. `shfmt` SILENTLY CORRUPTS hyphenated associative-array keys: `[cargo-deny]`
    becomes `[cargo - deny]` (it parses the `-` as arithmetic minus inside the
    subscript). Every `${MAP[cargo-deny]}` lookup then misses → blank/empty
    values with NO error. `shellcheck` does not catch it. Fix: ALWAYS quote
    hyphenated keys in both the declaration and the lookup —
    `['cargo-deny']='...'` and `"${MAP['cargo-deny']}"`. Quoted keys are
    shfmt-idempotent. Bit doctor.bash (tool-WHY map) and the ~/justfiles
    `categorize.sh` DESC map. After any `shfmt -w` on a file with assoc-array
    keys, grep for `' - '` inside `[...]=` to confirm no mangling.
25. Makefile bootstrapper `make <target>` forwarding: a plain
    `.DEFAULT: ; @just $(MAKECMDGOALS)` re-runs `just <goals>` ONCE PER GOAL
    (GNU make fires `.DEFAULT` for every unmatched target, each time passing
    the FULL `$(MAKECMDGOALS)` list) — so `make ci changelog` runs
    `just ci changelog` twice. Single-goal (the common `make test` case) is
    fine; multi-goal double-runs. Fix: forward exactly once by letting the
    first goal carry the whole list and making the rest no-ops, guarded so
    bare `make` (empty `MAKECMDGOALS`) still hits the `all:`/bootstrap rule:
    `ifneq ($(MAKECMDGOALS),)` /
    `$(firstword $(MAKECMDGOALS)): ; @just $(MAKECMDGOALS)` /
    `$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)): ; @:` / `endif`.
    (`$(MAKECMDGOALS)`/`$(firstword)`/`$(wordlist)`/`ifneq` are GNU-make
    extensions — already required by the `.DEFAULT` pattern, so `.POSIX:`
    here is aspirational/cosmetic, not strict.)
26. doctor.bash `version_of` cells lie silently: wrapper shims and multi-line
    `--version` formats defeat the generic
    `"$1" --version | head -1 | rg -No ...` branch. Bit on promptfoo
    (2026-07-03) by a since-removed git wrapper shim (`git` now resolves to
    plain `/opt/homebrew/bin/git`, so no special-case is needed there
    anymore); `shellcheck --version` has the number on line 2
    ("version: 0.11.0") so `head -1` yields EMPTY — special-case
    `rg -No 'version: ([0-9.]+)' -r '$1'`. bash -n/shellcheck can never catch
    these: EYEBALL every version cell in the real `just doctor` output.
27. A bash comment BEGINNING with `# shellcheck ...` inside a `case` statement
    is parsed as a shellcheck DIRECTIVE; directives are invalid in front of
    individual case branches → hard parse errors SC1124/SC1073 ("Couldn't
    parse this case item"). Bit monty's doctor.bash (2026-07-03) when a
    comment documented the shellcheck version special-case as
    "# shellcheck --version puts...". Reword so the comment does not start
    with the word `shellcheck`. bash -n cannot catch it.
28. `fact_loc` is a LINE count, not a file count: `fd -e X . dir -X gawk
    'END{print NR}'` hands the file LIST to one gawk that reads their
    CONTENTS (NR = total lines). The oh-my-codex reference lib.bash
    misdocuments it as a file count; labelling it "N file(s)" showed 26649
    "test case files" (real: 496). File count = pipe, no -X:
    `fd -e X . dir | gawk 'END{print NR}'`. Eyeball every splash fact —
    plausible big numbers hide unit bugs.
29. Upstream/third-party repos (origin = upstream, e.g. pydantic/monty):
    ship the harness LOCAL-ONLY via `.git/info/exclude` (append `/Justfile`
    and `/.just/`), never `.gitignore`; skip the Makefile bootstrapper when
    the project already has an authoritative Makefile — recipes delegate to
    `make <target>` so the Makefile stays the single source of truth.
30. jj-colocated repos sit on a DETACHED git HEAD, so
    `git rev-parse --abbrev-ref HEAD` returns the literal string `HEAD` and
    the splash shows "branch HEAD" (bit ~/maintenance, 2026-07-03).
    `fact_branch` must special-case it: when the answer is `HEAD` and
    `.jj/` exists, show `jj @ <id>` via `jj --ignore-working-copy log -r @
    --no-graph -T 'change_id.shortest(8)'` (`--ignore-working-copy` skips
    the snapshot, ~50ms, splash-safe). Related: repos with GENERATED
    markdown evidence (dated reports) need a `.rumdl.toml`
    `[global] exclude = [...]` so `just md-lint`/`verify` lint only
    hand-authored docs — never "fix" machine-emitted snapshot files.

## Verification (run ALL before claiming done)

```bash
chmod +x .just/helpers/*.bash
just --list --unsorted                          # parses; every recipe grouped + documented
just --dump --dump-format json | jq '.recipes | length'
for f in .just/helpers/*.bash; do bash -n "$f"; done
shellcheck -x -S warning -P .just/helpers .just/helpers/*.bash   # clean at warning severity
#   (info/style intentionally suppressed; lib.bash carries disable=SC2034 -- aim for
#    info-clean on NEW helpers, but -S warning is the enforced bar)
rg -n '\bclear\b|tput (clear|ed|E3)\b|\[[23]J' .just/helpers Justfile   # Iron Rule 5:
#   MUST be empty except explanatory comments -- zero screen-clearing anywhere
just doctor                                     # non-tty render + exit code
just info                                       # static splash renders
just <bare> </dev/null                          # default degrades to STATIC SPLASH (never --list) when non-tty
just -n <recipe-with-vars>                      # dry-run: interpolation reaches the tool
just --list --unsorted | rg -i 'currently|defined; |is\s*$'   # truncated doc-comment sweep
```

Plus one REAL invocation of a representative recipe (e.g. the build-system
gate) — dry-runs alone don't prove the wiring.

## Reference implementations

- `~/repos/ista-se/cas/ista-express/shared/kotlin-coding-challenge`
  (**most current — dual-TUI**: gum `menu.bash` + fzf `fzf.bash` + countdown
  splash with `--factoid` doctor + stty-based term size)
- `~/repos/ista-se/cas/ista-express/product-development/kotlin-lib-testbed`
  (Justfile + `.just/helpers/`, theme-free v3)
- `~/repos/ista-se/cas/ista-express/shared/be-hiring-challenge-solutions`
  (v3 origin; **WARNING — known-bad parts: its lib.bash still has the weak
  `>= 5` guard and `theme_load` hex palettes. NEVER copy those.**)
- `~/mysrc/g-foreach/Justfile` + `.just/helpers/` (single-crate Rust, **older**
  fzf-aliases style — structure ok, TUI predates dual-TUI v3)
- `~/projects/yagnit/` (single-crate Rust teaching SCM, **dual-TUI v3** ported
  from kotlin-coding-challenge: Makefile bootstrapper + 7 helpers, Cargo/mise/AI
  harness doctor catalogue, gated by shfmt `-i 2 -ci` + shellcheck + typos)
- `~/mysrc/gangsta/` (**build-less** markdown + bash AI-skills framework,
  **dual-TUI v3** ported from kotlin-coding-challenge: Makefile bootstrapper
  (with the once-only multi-goal forwarding from gotcha #25) + 9 helpers.
  Facts come from package.json + skills/commands/agents dir counts instead of
  a compiler; the doctor catalogue has NO jvm/build-tool (required:
  bash/just/git/python3/jq/rg/fd/gawk); `bash scripts/validate.sh` is the
  bootstrap "compile" step and `just test-install` (Docker) stands in for a
  build. The canonical example of the harness adapting to a project with no
  build system.)
- Memory: `mempalace search "justfile"` → wing `justfile_patterns`
  (`tui_design_v3` = house style, `gotchas` = pitfall batches).

## Self-improvement & memory (MANDATORY every invocation)

This skill is self-improving, self-correcting, self-updating. Every time it is
loaded for real Justfile work:

1. BEFORE designing: `mempalace search "justfile"` / `cortex query` for the
   latest patterns and gotchas; read the most-current dual-TUI reference
   (kotlin-coding-challenge) — never trust this doc alone if a reference is
   newer.
2. Consult `~/justfiles/INVENTORY.md` (generated) to find the closest existing
   Justfile to adapt — match by language/shape (e.g. Rust single-crate →
   yagnit / g-foreach). Refresh the inventory when stale:
   `bash ~/justfiles/scan.sh && bash ~/justfiles/categorize.sh`.
3. AFTER finishing: when a NEW gotcha bites or a pattern improves, append it to
   the Gotchas checklist here AND persist it — a verbatim drawer in mempalace
   wing `justfile_patterns` (room `gotchas`) and/or a `cortex/observe`. Do not
   double-write identical content to both (verbatim → mempalace; belief/pattern
   → cortex). Bump the `(vN)` version note in the title if the house style
   shifts materially.
4. Both skill copies (`~/.claude/skills/` and `~/.agents/skills/`) must stay
   byte-identical — edit one, copy to the other, verify with `diff -q`.
