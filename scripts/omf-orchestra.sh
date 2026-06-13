#!/usr/bin/env bash
#
# omf-orchestra.sh -- one-shot launcher for the omf build orchestration.
#
# Spins up a fresh tmux session in which Forge is the Orchestrator (boss),
# driving Codex (omx) and Claude (omc) as parallel workers that coordinate
# through `br` (beads) so no agent -- or its sub-agents -- steps on another's
# files. Run from OUTSIDE tmux:
#
#     bash ~/mysrc/oh-my-workbench/oh-my-forge/scripts/omf-orchestra.sh
#
# Layout (single window `orchestra`):
#     +---------------------+------------------+
#     |                     |   omc  (Claude)  |
#     |   forge             +------------------+
#     |   (Orchestrator)    |   omx  (Codex)   |
#     +---------------------+------------------+
#
# Forge boots empty, then receives a one-line bootstrap pointing at a freshly
# written brief (~/tmp/omf-orchestra-brief.md). Forge itself launches and
# drives the omc/omx panes via `tmux send-keys` -- the launcher does not race
# three TUI boots.

set -euo pipefail

# --- enforce GNU Bash >= 5.3 (re-exec under Homebrew bash if needed) ---------
if [[ -z ${OMF_BASH_REEXEC:-} ]] \
  && { [[ -z ${BASH_VERSINFO:-} ]] \
    || ((BASH_VERSINFO[0] < 5)) \
    || { ((BASH_VERSINFO[0] == 5)) && ((BASH_VERSINFO[1] < 3)); }; }; then
  exec env OMF_BASH_REEXEC=1 /opt/homebrew/bin/bash "$0" "$@"
fi

# --- colors (tput only, tty + NO_COLOR gated) -------------------------------
if [[ -t 2 && -z ${NO_COLOR:-} ]] && command -v tput > /dev/null 2>&1 \
  && (($(tput colors 2> /dev/null || echo 0) >= 8)); then
  C_RESET=$(tput sgr0) C_BOLD=$(tput bold)
  C_RED=$(tput setaf 1) C_GREEN=$(tput setaf 2) C_YELLOW=$(tput setaf 3)
  C_BLUE=$(tput setaf 4)
else
  C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

die() {
  printf '%s%s omf-orchestra:%s %s\n' "$C_BOLD" "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}
info() { printf '%s::%s %s\n' "$C_BLUE" "$C_RESET" "$*" >&2; }
ok() { printf '%s ok%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }

# --- guards -----------------------------------------------------------------
[[ -n ${TMUX:-} ]] && die "run this from OUTSIDE tmux (you are inside session: ${TMUX##*,})"

SESSION=${OMF_SESSION:-omf}
BOOT_WAIT=${OMF_BOOT_WAIT:-5}

need() { command -v "$1" > /dev/null 2>&1 || die "missing required tool: $1"; }
for t in tmux forge br; do need "$t"; done
# Workers are optional at launch -- forge will report if one is missing.
for t in omc omx; do
  command -v "$t" > /dev/null 2>&1 || info "${C_YELLOW}warn${C_RESET}: '$t' not on PATH -- forge will note it and continue"
done

# --- locate repo (script lives in <repo>/scripts/) --------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
PLAN="plans/2026-06-13-omf-control-plane-v1.md"
[[ -f "$REPO/$PLAN" ]] || die "plan file not found: $REPO/$PLAN"

# --- refuse to clobber an existing session ----------------------------------
if tmux has-session -t "$SESSION" 2> /dev/null; then
  die "tmux session '$SESSION' already exists. Attach: tmux attach -t $SESSION  |  or kill: tmux kill-session -t $SESSION"
fi

# --- ensure a beads workspace (shared coordination surface) -----------------
if [[ ! -d "$REPO/.beads" ]]; then
  info "initializing beads workspace (.beads/, prefix=omf)"
  (cd -- "$REPO" && br init --prefix omf > /dev/null) || die "br init failed"
  ok "beads workspace created"
else
  ok "beads workspace present ($REPO/.beads)"
fi

# --- write the pane-target map + the orchestrator brief ---------------------
mkdir -p "$HOME/tmp"
PANES_ENV="$HOME/tmp/omf-panes.env"
BRIEF="$HOME/tmp/omf-orchestra-brief.md"

# --- build the tmux session -------------------------------------------------
info "creating tmux session '$SESSION' in $REPO"
FORGE_PANE=$(tmux new-session -d -s "$SESSION" -n orchestra -c "$REPO" -PF '#{pane_id}')
OMC_PANE=$(tmux split-window -h -l '45%' -t "$FORGE_PANE" -c "$REPO" -PF '#{pane_id}')
OMX_PANE=$(tmux split-window -v -l '50%' -t "$OMC_PANE" -c "$REPO" -PF '#{pane_id}')

tmux select-pane -t "$FORGE_PANE" -T 'forge (ORCHESTRATOR)'
tmux select-pane -t "$OMC_PANE" -T 'omc (Claude worker)'
tmux select-pane -t "$OMX_PANE" -T 'omx (Codex worker)'
tmux set-option -t "$SESSION" pane-border-status top > /dev/null 2>&1 || true
tmux set-option -t "$SESSION" pane-border-format ' #{pane_title} ' > /dev/null 2>&1 || true

# Persist real pane ids so the brief/forge can target panes unambiguously.
cat > "$PANES_ENV" << EOF
# Written by omf-orchestra.sh -- pane targets for the running session.
OMF_SESSION='$SESSION'
OMF_REPO='$REPO'
OMF_PANE_FORGE='$FORGE_PANE'
OMF_PANE_OMC='$OMC_PANE'
OMF_PANE_OMX='$OMX_PANE'
EOF
ok "pane map -> $PANES_ENV"

# Worker panes idle as labeled shells; forge launches+drives them.
tmux send-keys -t "$OMC_PANE" -l "clear; printf '%s\n' 'OMC worker pane -- idle. The Orchestrator (forge) will launch \`omc launch --madmax\` here and dispatch beads-tracked tasks.'"
tmux send-keys -t "$OMC_PANE" C-m
tmux send-keys -t "$OMX_PANE" -l "clear; printf '%s\n' 'OMX worker pane -- idle. The Orchestrator (forge) will launch \`omx --madmax\` here and dispatch beads-tracked tasks.'"
tmux send-keys -t "$OMX_PANE" C-m

# --- the Orchestrator brief -------------------------------------------------
cat > "$BRIEF" << 'BRIEF_EOF'
# omf build -- ORCHESTRATOR BRIEF (you are Forge, the boss)

You are **Forge**, running as the **Orchestrator** of a 3-agent parallel build.
Your two workers are **Codex (omx)** and **Claude (omc)**, each in its own tmux
pane in this session. You divide the work, dispatch it, and integrate it. You
ALSO carry your own lane. Use your FULL arsenal: sub-agents via `task`
(architect, critic, executor-high, security-reviewer, test-writer, verifier,
db-engineer, etc. -- all revived), skills (`plan`, `tdd`, `verify`,
`code-review`, `security-review`, `ralph`), and the whole toolchain.

## 0. Wake up: load your context first
1. `cat ~/tmp/omf-panes.env` -- your pane targets (OMF_PANE_FORGE / _OMC / _OMX).
2. Read `plans/2026-06-13-omf-control-plane-v1.md` IN FULL -- the authoritative design.
3. `br ready --json` and `br list --json` -- current coordination state.
4. Recall memory if useful: cortex decision `b98826a4`, mempalace drawer
   `oh-my-forge/omf-architecture`.

## 1. Coordination substrate: `br` (beads) -- NON-NEGOTIABLE
All work is tracked as beads issues in `./.beads/` (already initialized,
prefix `omf`). This is how three agents avoid stepping on each other.

- Create one issue per task: `br create -t task -p P1 -a <forge|omc|omx> -l <lane> "title" -d "body"`.
- Dependencies so blocked lanes never start early: `br dep add <issue> <depends-on>`.
- A worker CLAIMS atomically before touching files: `br update <id> --assignee <self>`
  (sets assignee + status=in_progress in one shot -- this is the lock).
- Close on done: `br update <id> -s closed`. Then `br sync` to flush JSONL.
- Before ANY file write, the owning agent must hold the claim for an issue whose
  lane covers that file. No claim -> no write.

## 2. Lane division -- DISJOINT FILE OWNERSHIP (the anti-collision rule)
Everything lives under `omf/` in this repo. Ownership is by directory + language
so two agents can never edit the same file:

- **FORGE (you) -- the compiled SECURITY FLOOR (Rust).** Owns `omf/core/`
  (crate `omf-core`: secrets via the read-only `mein-zsh-op-cache` keychain +
  `op` private-vault read/write, env allowlist keyed by account+op-account,
  memory-guard admission preflight), `omf/omf.toml` (schema + clamp rules),
  and the Cargo workspace manifests. You also OWN INTEGRATION + REVIEW.
- **OMX (Codex) -- the Go dispatcher.** Owns `omf/dispatch/` (all `.go`):
  the CLI router, the compiled work<>private routing invariant + its unit test,
  `omf llm` over the existing llama-swap substrate, `omf llm mlx` adopting the
  proven `~/.local/bin/mlx_lm_server_safe` wrapper VERBATIM (wired<=14 / mem<=18
  / cache<=2 -- never reinvent it), and `omf doctor` incl. the 3 MLX-drift checks.
- **OMC (Claude) -- Bash + house-style + Python.** Owns `omf/adapters/` (bash:
  reuse `fcr` / `forge-hist` pickers verbatim for `omf resume` / `omf hist`),
  the `omf/registrar/` Python (uv, footprint calc), and the `Justfile` +
  `.just/helpers/` wiring (`go` / `cargo` / `omf` recipes folded under `just ci`).
  OMC is the ONLY agent that edits `Justfile` -- all recipe requests route to OMC
  via a br issue to serialize that shared file.

HARD RULES carried from the design:
- **Never reimplement an upstream subcommand** (forge/omc/omx/claude/codex):
  discovery + transparent passthrough ONLY. Reimplementation = rot.
- The security-critical Go routing invariant test (omx) is gated: open a br
  issue `forge review: routing invariant` that BLOCKS omx's routing close;
  you (forge) run `critic` + `security-reviewer` sub-agents before closing it.
- No `git push`, no force-push, no history rewrite without the human's OK.
  Treat any `upstream` remote as read-only. Commit via `git` (zagi) with
  `-m` + `--prompt` and Lore trailers (Constraint/Rejected/Confidence/Tested).

## 3. How to drive the worker panes
Launch them (once), then dispatch by sending their prompt + Enter. Verify a
pane is alive with `tmux capture-pane -p -t <pane>` before dispatching.

    OMC=$(grep OMF_PANE_OMC ~/tmp/omf-panes.env | cut -d"'" -f2)
    OMX=$(grep OMF_PANE_OMX ~/tmp/omf-panes.env | cut -d"'" -f2)
    tmux send-keys -t "$OMC" -l 'omc launch --madmax' ; tmux send-keys -t "$OMC" C-m
    tmux send-keys -t "$OMX" -l 'omx --madmax'        ; tmux send-keys -t "$OMX" C-m
    # ...wait for boot, capture-pane to confirm the prompt, then:

NON-NEGOTIABLE: launch BOTH workers in **--madmax** (yolo / auto-approve, no
1/2 approval gates). The flag is mandatory for omc AND omx -- never launch a
worker without it. This is the "trio-infernale" forever-loop mode.
    tmux send-keys -t "$OMX" -l 'Read ~/tmp/omf-orchestra-brief.md sections 1-2 and 4. You are the OMX worker. Claim and execute every br issue assigned -a omx. Use your full team/swarm + sub-agents. Coordinate ONLY via br; never touch files outside omf/dispatch/.'
    tmux send-keys -t "$OMX" C-m

Give omc the analogous worker prompt scoped to its lane (omf/adapters,
omf/registrar, Justfile). Each worker uses its OWN full arsenal (omx team/swarm,
omc team/agents) -- you set the goal and the lane, they decide how.

## 4. Execution loop (you, the Orchestrator)
1. Decompose `plans/...-v1.md` v1 scope into atomic br issues, one lane each,
   with deps (e.g. dispatch's secrets call depends on forge's omf-core stub;
   Justfile `cargo`/`go` recipes depend on the crates existing).
2. Assign: `-a forge` / `-a omc` / `-a omx`. Set cross-lane deps so nobody is
   blocked-but-working.
3. Launch + brief both workers (section 3). Then START YOUR OWN lane (omf/core)
   in parallel -- do not idle while workers run.
4. Poll `br ready --json` and `tmux capture-pane` periodically. Unblock,
   re-dispatch, and run review gates (critic/security-reviewer/verify) as
   issues close.
5. Integration: keep `just ci` green at every merge point. A lane is "done"
   only when its br issue is closed AND `just ci` is green AND you've verified
   it (the `verify` skill), not when a worker says so.
6. Report to the human after the issue graph is created (the plan-of-record),
   and again at each lane completion. Keep reports terse: changed files,
   what was verified, remaining risk.

## 5. First actions, right now
1. `cat ~/tmp/omf-panes.env` and read the plan.
2. Create the br issue graph for v1 (all three lanes, with deps) and `br sync`.
3. Print the issue graph (`br dep tree` / `br list`) to the human as the
   plan-of-record and SAY which lane each agent owns.
4. Launch + brief omx and omc in their panes.
5. Begin your own omf/core lane.
Go.
BRIEF_EOF
ok "orchestrator brief -> $BRIEF"

# --- boot forge, then inject the bootstrap one-liner ------------------------
info "launching forge (Orchestrator) -- waiting ${BOOT_WAIT}s for boot before bootstrap"
tmux send-keys -t "$FORGE_PANE" -l 'forge'
tmux send-keys -t "$FORGE_PANE" C-m
sleep "$BOOT_WAIT"
tmux send-keys -t "$FORGE_PANE" -l 'You are the omf build ORCHESTRATOR. Read ~/tmp/omf-orchestra-brief.md in full and execute it exactly -- create the br issue graph, divide the 3 lanes, launch and brief the omc/omx worker panes, then run your own omf/core lane. Begin now.'
tmux send-keys -t "$FORGE_PANE" C-m

tmux select-pane -t "$FORGE_PANE"

if [[ -n ${OMF_NO_ATTACH:-} ]]; then
  ok "session '$SESSION' ready (not attaching; OMF_NO_ATTACH set)"
  info "attach with: tmux attach -t $SESSION"
  exit 0
fi
ok "session '$SESSION' ready -- attaching"
exec tmux attach -t "$SESSION"
