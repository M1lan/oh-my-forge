# Local-model forge launcher (generalize forge-gemma to all ~/models/) — v1

## Objective

Let forge start against any locally-served model in `~/models/` with one
picker command, instead of the current gemma4-only, hardcoded launcher.
Forge already ships a `llama_cpp` provider (OpenAI-compatible, pointed via
`LLAMA_CPP_HOST`/`LLAMA_CPP_PORT` env vars) and a working reference
implementation already exists at
`~/gemma4-12B-coder-f5/forge-gemma.bash:1-101` — it just hardcodes one model
and a stale port. This plan generalizes that pattern to every model
llama-swap currently serves, discovered dynamically, and fixes the port
drift found along the way.

## Revision history

- v1 (2026-07-09): initial plan.

## Naming clarification (surfacing an assumption — RULE 0)

The request said "omf launcher." Two things could match that name:

1. `~/forge/omf/` — a Rust+Go control-plane project. Confirmed UNFINISHED:
   `omf.toml:15-41` is placeholder example rows (`schema_version = 0`), and
   `omf llm` (discover+list llama-swap/ollama models) is an open `[ ]`
   roadmap item in `plans/2026-06-13-omf-control-plane-v1.md:93,170` with no
   Go dispatcher code behind it yet. `AGENTS.md` explicitly says not to
   build on it unprompted.
2. The already-working `forge-gemma.bash` pattern at
   `~/gemma4-12B-coder-f5/forge-gemma.bash` — a real, running launcher that
   already does 90% of what was asked, for one model.

This plan builds on (2), not (1): it is smaller, already proven, and does
not require standing up the omf Go/Rust binary. Phase D notes how this
slots into `omf llm` later if that project is ever finished — nothing here
is wasted if it is.

## Scope

**In scope:**

- Fix the stale `:8080` → `:4321` llama-swap port in the two existing
  gemma launchers (confirmed dead: `:8080` refuses connections, `:4321`
  returns `200` on `/health`).
- A new generalized launcher script that discovers every model currently
  registered in llama-swap (dynamic, via its own `/v1/models`) and lets the
  user fzf-pick one, then launches forge pointed at it via the `llama_cpp`
  provider.
- Registering the one orphaned on-disk model
  (`~/models/mlx/qwen2.5-coder-3b-opus46-distilled-8bit`, flagged as an open
  question in `~/models/notes.org:169-172`) into llama-swap, with
  memory-safety tuning matching the existing `qwen36-mlx` entry — presented
  as a reviewable diff, not auto-applied.
- Flagging (not fixing) the divergent self-hosting `forge-gemma` variant at
  `~/scripts/tools/forge-gemma/` that bypasses llama-swap's idle-unload
  memory guardrail.

**Out of scope (explicit non-goals):**

- Building the `omf/` Go dispatcher `omf llm` subcommand for real. That is
  its own, much larger, already-tracked roadmap item.
- Auto-registering every possible on-disk model (HF hub cache, ryzdfm
  checkpoint) into llama-swap without a human reviewing memory caps —
  `~/models/notes.org:173-175` already flags the ryzdfm checkpoint as a
  prune candidate, not a registration candidate.
- Rewriting or deleting `~/scripts/tools/forge-gemma/` (no deletion without
  explicit permission; it also has its own jj-tracked config dir this plan
  does not touch).
- Changing Ollama's model store location or the `~/models/ollama` /
  `~/.ollama` split — already handled by the in-flight model-consolidation
  work in `~/models/notes.org`.
- A cloud-model picker — this is local-only, by request.

## Ground Truth

- Forge ships a built-in `llama_cpp` provider driven by
  `LLAMA_CPP_HOST`/`LLAMA_CPP_PORT`/`LLAMA_CPP_SSL_SCHEME` (with legacy
  fallback `LLAMA_CPP_URL`):
  `/Users/milan.santosi/mysrc/forgecode/crates/forge_repo/src/provider/provider.json:1393-1399`,
  fallback mapping at
  `/Users/milan.santosi/mysrc/forgecode/crates/forge_repo/src/provider/provider_repo.rs:104-111`.
  `forge_main/src/ui.rs:3233` confirms `llama_cpp` is in the allow-list of
  providers that accept a local (non-real) API key.
- `forge config set model <provider> <model>` sets `[session]` in
  `~/forge/.forge.toml` atomically (verified: `forge config set model
  --help`). No per-invocation `--model` CLI flag exists — the launcher must
  shell out to this command before running `forge`.
- llama-swap is the actual serving substrate for every local model, run as
  LaunchAgent `com.user.llama-swap`, config at
  `~/.config/llama-swap/config.yaml` (gitignored — confirmed via
  `git -C ~/.config check-ignore -v llama-swap/config.yaml` →
  `.gitignore:5:/*llama-swap/config.yaml`). It already listens on `:4321`
  (moved from `:8080` on 2026-07-04 per
  `~/.config/llama-swap/config.yaml:1-8`) and exposes an OpenAI-compatible
  `/v1/models` that lists every registered model key — verified live:
  `curl :4321/v1/models` returns
  `{"data":[{"id":"/Users/milan.santosi/models/mlx/qwen36-mlx",...},
  {"id":"gemma4-coder",...}, ...]}`.
- Currently registered in llama-swap (`~/.config/llama-swap/config.yaml:32-185`):
  `/Users/milan.santosi/models/mlx/qwen36-mlx`, `qwen3-coder:latest`,
  `qwen3.6:27b`, `gemma4-coder`, `mlx-community/Llama-3.2-3B-Instruct-4bit`,
  `sahilchachra/Qwythos-9B-Claude-Mythos-5-1M-mxfp4-mlx`, and (registered but
  not in the active swap group)
  `hf.co/empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF:Q6_K`.
- On-disk under `~/models/` but NOT reachable via llama-swap today:
  `~/models/mlx/qwen2.5-coder-3b-opus46-distilled-8bit` — explicitly flagged
  in `~/models/notes.org:169-172` as "zero references anywhere... ask if it
  should be registered somewhere or is dead weight." This plan answers
  that: register it.
  `~/models/huggingface/hub/models--ryzdfm--qwen2.5-coder-3b-claude_opus_4.6-distilled`
  is the unconverted source checkpoint for the model above and is flagged
  as a **prune candidate** in `~/models/notes.org:173-175` — do not
  register this one, it is superseded.
  `~/models/huggingface/hub/models--mlx-community--Qwen2.5-Coder-3B-Instruct-8bit`
  and the docling models are not chat models registered anywhere and are
  left untouched (not requested, not flagged as orphaned-but-wanted).
- A working reference launcher already exists:
  `~/gemma4-12B-coder-f5/forge-gemma.bash:27-29` sets
  `PROVIDER_ID='llama_cpp'`, `MODEL_ID='gemma4-coder'`,
  `SWAP_URL='http://127.0.0.1:8080'` — the port is stale (verified dead
  above). Lines 44-58 health-check llama-swap and verify the model is
  registered before proceeding; lines 60-97 save the previous
  provider/model, switch to the target one via `forge config set model`,
  run forge, and restore the previous default on exit via a `trap ... EXIT`
  (line 93). This save/switch/restore pattern is exactly what the
  generalized launcher should keep — it's proven and already handles the
  main footgun (leaving forge permanently pointed at a dead local model
  after the session ends).
- Sibling `~/gemma4-12B-coder-f5/opencode-gemma.bash:47` has the identical
  stale `:8080` for opencode's equivalent local-model launcher — same fix
  applies there since it targets the same llama-swap instance.
- A DIFFERENT, older tool at `~/scripts/tools/forge-gemma/` (own
  `bin/forge-gemma.bash`, `lib/server.bash`, `lib/config.bash`) does NOT use
  llama-swap at all — `lib/server.bash:30-61` spawns its own `llama-server`
  process directly and manages it via a PID file. This bypasses the
  idle-unload + memory-cap substrate that the whole `~/models/` /
  llama-swap setup exists to enforce (see the 03:07 freeze postmortem in
  `~/.config/llama-swap/config.yaml:1-9`). It is a separate, likely
  superseded generation of the same idea — flagged, not touched.
- MLX memory-safety pattern to replicate when registering the orphaned
  model (`~/.config/llama-swap/config.yaml:43-60`): wrapped through
  `mlx_lm_server_safe` (`~/.local/bin/mlx_lm_server_safe:1-50`, hard caps
  wired≤14 GiB / memory≤18 GiB / cache≤2 GiB), plus
  `--prefill-step-size 512 --prompt-concurrency 1 --decode-concurrency 1`
  and a small prompt cache — the file's own comments (lines 35-41) explain
  these exist because the model's working set is close to the machine's
  Metal wired budget.

## Implementation Plan

### Phase A — Fix the confirmed-dead port

- [ ] A1. `~/gemma4-12B-coder-f5/forge-gemma.bash:29`: change
  `SWAP_URL='http://127.0.0.1:8080'` → `'http://127.0.0.1:4321'`. Acceptance:
  `./forge-gemma.bash server status`-equivalent health probe
  (`curl -fsS http://127.0.0.1:4321/health`) succeeds and the script's own
  step-1 health check passes without kickstarting the LaunchAgent.
- [ ] A2. `~/gemma4-12B-coder-f5/opencode-gemma.bash:47,70`: same port fix
  (both the `SWAP_URL` var and the embedded `baseURL` in the generated
  `opencode.json`). Acceptance: same health check passes; if
  `~/.opencode-local-llm-gemma4-12/opencode.json` already exists from a
  prior run with the old baseURL baked in, it must be regenerated or
  patched too (the script only writes it `if [[ ! -f "$CONFIG_FILE" ]]` —
  check for an existing stale copy before assuming the source fix is
  enough).

### Phase B — Generalized multi-model launcher

- [ ] B1. Decide and confirm the script's location and name with the
  operator before writing it — natural candidate is a new tool under
  `~/scripts/tools/` (sibling of the existing `forge-gemma/`), e.g.
  `~/scripts/tools/local-forge/bin/local-forge.bash`, so it doesn't get
  confused with either existing `forge-gemma` variant. Acceptance: operator
  confirms name/location before B2 starts.
- [ ] B2. Discovery: `curl -fsS http://127.0.0.1:4321/v1/models | jq -r
  '.data[].id'` to list every model llama-swap currently knows about
  (dynamic — stays correct as `config.yaml` changes, no separate parsing of
  `~/models/` needed for this list). Acceptance: output matches the model
  keys in `~/.config/llama-swap/config.yaml:32-185` at time of writing.
- [ ] B3. Picker: pipe the B2 list through `fzf` (project convention,
  `AGENTS.md:11` snippets) for interactive selection; accept a
  `--model <id>` flag for non-interactive use. Acceptance: both interactive
  and flag-driven selection produce the same downstream behavior.
- [ ] B4. Launch sequence, mirroring
  `~/gemma4-12B-coder-f5/forge-gemma.bash:60-97`: health-check llama-swap on
  `:4321` (kickstart the `com.user.llama-swap` LaunchAgent if down, same
  retry loop as the reference script) → save current
  `forge config get provider`/`forge config get model` → `forge config set
  model llama_cpp <picked-id>` → `exec forge "$@"` → restore the saved
  provider/model in a `trap ... EXIT` handler. Acceptance: after a session
  with a local model, `forge config get model` shows the pre-session
  default again, not the local model.
- [ ] B5. Skip the MCP-swapping behavior from `forge-gemma.bash:66-78,87-91`
  by default (that's a gemma-12B-specific prompt-size optimization, not a
  generic requirement) — add it back only if the operator asks for it once
  they've used the generalized version.
- [ ] B6. Bash 5.3+, `shellcheck -x` + `shfmt -w -i 2 -ci -sr` clean, per
  house style (`AGENTS.md` §9/§21).

### Phase C — Register the orphaned MLX model

- [ ] C1. Draft a new llama-swap entry for
  `~/models/mlx/qwen2.5-coder-3b-opus46-distilled-8bit` in
  `~/.config/llama-swap/config.yaml`, copying the `qwen36-mlx` pattern
  (`mlx_lm_server_safe`, `--prefill-step-size 512`, concurrency 1, capped
  prompt cache) since it is also MLX-served and subject to the same wired-
  memory ceiling. Present the diff to the operator — do not apply
  unattended (this file is hand-tuned per-model; §17.1 security/privacy-
  first and the general never-surprise-the-operator stance both argue for
  a review step here, not silent automation).
- [ ] C2. On approval, add it to `groups.llm.members`
  (`~/.config/llama-swap/config.yaml:172-185`) so the one-model-at-a-time
  rule still holds, then `launchctl kickstart -k
  gui/$(id -u)/com.user.llama-swap` to reload. Acceptance:
  `curl :4321/v1/models` lists the new id; a `forge-gemma`-style smoke
  request against it completes without triggering swap or memory alarms.

### Phase D — Future omf integration note (documentation only, no code)

- [ ] D1. Add a one-paragraph pointer in
  `plans/2026-06-13-omf-control-plane-v1.md`'s `omf llm` roadmap item
  (line 93/170) noting that Phase B's discovery command
  (`curl :4321/v1/models`) is exactly what `omf llm list` should shell out
  to once the Go dispatcher exists — so this work is directly reusable,
  not orphaned, if `omf` is ever finished.

## Verification Criteria

- ✅ `curl -fsS http://127.0.0.1:4321/health` returns 200 (already true;
  regression-check after A1/A2).
- ✅ Neither `forge-gemma.bash` nor `opencode-gemma.bash` reference `:8080`
  anywhere (`rg -n '8080' ~/gemma4-12B-coder-f5/*.bash` returns nothing).
- ✅ The new launcher, run non-interactively against every id returned by
  `curl :4321/v1/models`, successfully sets `forge config get model` to
  that id and restores the prior default on exit (loop over all ids, not
  just gemma).
- ✅ After Phase C, `curl :4321/v1/models` includes
  `sahilchachra...` (unchanged) plus the new
  `qwen2.5-coder-3b-opus46-distilled-8bit` id, and a real completion request
  against it succeeds without triggering a memory-pressure warning in
  `~/logs/llama-swap.err.log`.

## Potential Risks and Mitigations

1. **Two divergent `forge-gemma` implementations already exist and diverge
   on memory safety.** The generalized launcher must be built on the
   llama-swap-delegating variant (`~/gemma4-12B-coder-f5/forge-gemma.bash`),
   never the self-hosting `~/scripts/tools/forge-gemma/` variant, or the
   03:07 freeze failure mode comes back. **Mitigation:** Phase B explicitly
   cites the correct reference implementation; Phase A/B never touch
   `~/scripts/tools/forge-gemma/`.
2. **`forge config set model` is a global, stateful mutation** — running
   two local-model sessions concurrently (or one crashing before its `trap
   EXIT` restore runs) can leave forge's default silently pointed at a dead
   local model. **Mitigation:** keep the existing save/restore-on-exit
   pattern from Phase B4; document the known gap (SIGKILL bypasses the
   trap) rather than solving it — same limitation the reference script
   already accepts.
3. **Hand-tuned llama-swap entries are not blindly reproducible.** Getting
   the MLX caps wrong for the new model could reintroduce the memory
   freeze. **Mitigation:** Phase C is diff-and-review, not auto-apply; no
   `[[backend.limits]]`-style automation is invented here.
4. **`llama_cpp` provider may require a non-empty (dummy) API key** even
   though llama-swap performs no auth. **Mitigation:** verified pattern
   already works in the existing reference script without extra
   configuration — carry that forward as-is; test during B4 rather than
   assume.

## Alternative Approaches

1. **Custom `[[providers]]` block in `~/forge/.forge.toml`** with
   `models = "http://127.0.0.1:4321/v1/models"` (confirmed supported:
   `forge_config/src/config.rs:475-495`). Trade-off: one-time setup, but
   duplicates what the built-in `llama_cpp` provider already does, and adds
   a permanent block to the global config that a generalized launcher
   would then have to keep in sync with llama-swap's dynamic list anyway.
   Rejected because: the existing `llama_cpp` provider already does dynamic
   discovery and is already proven working in `forge-gemma.bash` — no need
   for a second, parallel provider definition.
2. **Build `omf llm` for real** (the Go dispatcher subcommand already on
   the omf roadmap). Trade-off: eventually the "correct" long-term home,
   with compiled routing safety and `omf doctor` integration. Rejected for
   this plan because: the omf Go dispatcher doesn't exist yet — building it
   is a multi-week project of its own (`plans/2026-06-13-omf-control-plane-v1.md`),
   and the ask here ("start forge with either of these models easily") is
   satisfiable today with ~150 lines of Bash reusing proven code.

## Execution Notes

- Run via `execute-plan` or hand off Phase A (mechanical, low-risk) to
  `executor-low`, Phase B to `executor` (needs the `write-bash` skill
  loaded per house style), and get explicit operator sign-off before
  Phase C touches the gitignored, hand-tuned `~/.config/llama-swap/config.yaml`.
- Phase D is a two-line doc edit, safe to bundle with Phase A/B.
- Confirm B1's script name/location with the operator before writing any
  code for Phase B — this plan deliberately leaves that one open rather
  than guessing.
