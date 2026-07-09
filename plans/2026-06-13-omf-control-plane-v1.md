# omf — the unified AI-coding control plane (v1 plan)

Date: 2026-06-13 · Status: planning · Owner: forge + user
Location: in-repo under `~/mysrc/oh-my-workbench/oh-my-forge/omf/`

## 1. Goal

`omf` (oh-my-forge) is the user's **last AI-coding harness wrapper/launcher**: one
modular, pluggable, tmux-native control plane that fronts every AI-coding surface on
this single macOS machine (M4 Pro / 24 GiB) and makes `omc`/`omx` redundant.
`forge` is the primary orchestrator (primus inter pares); it can spawn
`claude`/`codex` — or `omc`/`omx` — in tmux sub-panes of the same session it controls.
Full CLI **and** full TUI. This is an ongoing effort, not a one-shot.

Design stance (decided): **control-plane by discovery**, not reimplementation. omf
discovers and registers the AI tooling already present (forge profiles, omc, omx,
claude/codex/gemini/copilot, ollama, llama-swap, mlx) and presents a unified plane
over them. It owns *routing, safety, and orchestration*; it does not re-implement the
tools' own subcommands.

## 2. Non-goals

- [ ] NOT a reimplementation of any backend's subcommands (transparent exec passthrough).
  **HARD RULE (enforced):** omf NEVER reimplements an upstream subcommand; discovery +
  passthrough only. The day omf reimplements an omc/omx/forge subcommand is the day it
  starts rotting on that tool's release cadence.
- [ ] NOT a guarantee that an over-budget MLX model "fits" — it cannot (see §6).
- [ ] NOT a second writer of the `mein-zsh-op-cache` keychain item (zsh owns writes there).
- [ ] NOT JS/TS, in any module.

## 3. Architecture (hybrid, language-per-job)

```
user / zsh / emacs ─▶ omf  (Go)  CLI dispatcher + TUI launcher
                       • discovery/registry • manifest load+clamp • argv routing
                       • env assembly + exec mode-dispatch
                       │
        ┌──────────────┼───────────────┬───────────────┬──────────────┐
   compiled floor   shell out      shell out        call core     plugin exec
        ▼              ▼               ▼                ▼              ▼
  ROUTING (Go)     Bash TUIs       tmux orch (Go)   omf-core (Rust)  omf-backend-*
  account→HOME     fcr / hist /    panes/sessions   guard + secrets  (external,
  work≠private     ai-menu /       forge-as-driver  (tiny audited)   thin contract)
  literals+test    compose(emacs)
                                                    local-LLM via llama-swap/ollama
```

Languages:
- **Go** — dispatcher, routing (compiled work≠private invariant + unit test), tmux
  orchestration, local-LLM lifecycle (talks to the existing `llama-swap` + `ollama`).
- **Rust (`omf-core`)** — one small audited binary: memory-guard (admission +
  single-flight + watchdog) and secrets (zeroize, env allowlist). Safety-critical only.
- **Bash 5.3.12** — reuse the tuned TUIs verbatim (`fcr`, `forge-hist`, `ai` menu) +
  `gum`/`fzf`/`tput` helpers under the existing `.just/helpers` pattern.
- **Python/uv** — offline model registrar (reads safetensors headers → manifest rows).
  Not a runtime dependency.

## 4. Plugin contract (day-zero extensibility)

A **backend** is the unit of pluggability. Two ways to add one, no core recompile:
1. **Manifest entry** in `omf.toml`: `name`, `kind` (forge|claude|codex|omc|omx|
   vendor|local-llm), oneshot/interactive command templates (argv arrays — never shell
   strings, to avoid the `ai-dispatch.zsh:296-302` eval-quoting footgun), routing class
   (none|work|private), env-allowlist, danger-allowed.
- [ ] Define the manifest schema + a `serde`/Go struct + `omf doctor` validation.
2. **External executable** `omf-backend-<name>` (git-style) implementing a thin JSON
   stdin/stdout contract: `describe`, `spawn --pane`, `oneshot`. Discovered on PATH and
   in `omf/backends/`.
- [ ] Define + document the external-backend protocol (versioned).

Built-in backends ship as manifest rows: forge (×6 profiles), claude, codex, omc, omx,
gemini, copilot, crush, aider, local-llm. Adding a model/account/vendor = edit TOML.
Adding a *safety-critical* route (new isolated plan) = deliberate code change to the floor.

## 5. Compiled floor vs declarative config

The manifest may only ever request **stricter** limits; the compiled core clamps looser
values and logs the clamp ("minimum wiggle room for critical mistakes").

- Compiled: account→`FORGE_CONFIG` table, work≠private assertion, provider/model
  literals, `OS_RESERVE`, admission formula, max wired-limit, secrets invariants.
- Config (`omf.toml`): tool catalog, model rows, labels, ports, tmux names, reasoning.

## 6. Local-LLM memory safety (reframed around prior art)

Discovery: the user **already** runs `llama-swap` (config `~/.config/llama-swap/config.yaml`,
`groups.llm: {swap: true, exclusive: true}` = one model at a time) fronting:
`qwen36-mlx` via a `mlx_lm_server_safe` wrapper (wired ≤14 GiB), `qwen3-coder:latest`
(GGUF/ollama, pageable), `qwen3.6:27b` (GGUF/ollama, pageable). A 03:07 MLX freeze is
documented in that config.

omf **adopts** llama-swap as the engine substrate instead of reinventing lifecycle:
- [ ] `omf llm` talks to llama-swap (`:4321` — moved from `:8080` on 2026-07-04) +
  `ollama` (`:11434`); lists/loads/unloads. Prior art already exists and is proven:
  `~/scripts/tools/local-forge/bin/local-forge.bash` (`plans/2026-07-09-local-model-forge-launcher-v1.md`)
  discovers models via llama-swap's own `/v1/models`, fzf-picks one, and drives forge's
  `llama_cpp` provider end-to-end. When `omf llm` is actually built, port that script's
  discovery/pick/restore logic into the Go dispatcher instead of re-deriving it.
- [ ] Admission preflight (Rust) is a *light backstop*, not the primary defense: it warns
  if `peak_RSS` would exceed claimable. The proven `set_wired_limit(14 GiB)` split (§6a)
  is what actually prevents the freeze. No refuse-by-default for MLX — the model runs;
  worst case is a slow/failed request, never a dead machine.
- [ ] Single-flight `flock` `~/.cache/omf/runtime.lock` (belt-and-braces with llama-swap's
  `exclusive`).
- [ ] MLX in-process caps (the proven path, §6a): `set_wired_limit(14 GiB)`,
  `set_memory_limit(18 GiB)`, `set_cache_limit(2 GiB)`, `--prompt-cache-bytes`,
  `--max-tokens`, small ctx.
- [ ] Watchdog (Phase 1): 2 Hz, swapouts-rate/free-page thresholds, SIGTERM→SIGKILL.
- [!] Root `iogpu.wired_limit_mb` cap is NOT used in v1 (userspace caps + the existing
  `mlx_lm_server_safe` wrapper already prove the no-root path). Optional later via jamf sudo.

### 6a. MLX done right — adopt the proven `set_wired_limit` split (NO process suspension)

The model does NOT need to shrink and the machine does NOT need to be quiesced. The
existing `mlx_lm_server_safe` wrapper (`~/.local/bin/mlx_lm_server_safe:1-46`) already
solves the freeze, via MLX's wired/pageable split:
- `mx.set_wired_limit(14 GiB)` pins at most 14 GiB; the remaining ~3.6 GiB of the 17.6 GiB
  model stays **pageable**, so the OS always keeps ~10 GiB it can reclaim → graceful
  degradation like GGUF mmap. Worst case = slow/failed request, never a dead machine.
- `mx.set_memory_limit(18 GiB)` makes the allocator error near the cap instead of MLX's
  ~27 GiB default; `set_cache_limit(2 GiB)` returns freed buffers to the OS.
- llama-swap adds: prefill-step 512 (quarters the prefill spike behind the 03:07 freeze),
  concurrency 1, prompt-cache 1 entry / 1 GiB, idle-TTL unload, one-model-at-a-time.

omf **adopts this verbatim** as the canonical MLX path (`omf llm mlx`): surface and manage
the existing wrapper + llama-swap entry, never reinvent it, **never suspend other
processes**.
- [ ] `omf llm mlx` launches via the proven wrapper; `omf doctor` verifies the wired/mem
  caps are actually in effect before first use.
- [ ] Admission + watchdog remain *light backstops* only.
- Optional max-headroom MLX: the 14 GiB Q2_K_XL repack (~63.7 tok/s) for more slack at
  some quality cost. GGUF (Qwen2.5-Coder-14B / Qwen3-Coder-30B-A3B) stays the zero-risk
  option.

Recommended default coding model (pageable, safe): **Qwen2.5-Coder-14B Q4_K_M (~9 GiB)**
or **Qwen3-Coder-30B-A3B ≤14 GiB GGUF**, served via ollama behind llama-swap. The
qwen36-mlx model cannot be cleanly converted to GGUF (it is a pre-quantized 3-bit MLX
checkpoint; conversion needs the ~66 GB BF16 original) and cannot be meaningfully shrunk
by "removing languages" (knowledge is not language-separable; the size is 256 MoE experts).

## 7. Secrets (read + write private vault, per user grant)

- [ ] Read the existing `mein-zsh-op-cache` keychain hands-off via `/usr/bin/security`
  (no Touch ID), TSV-not-source (`op-secrets.zsh:86-112` semantics) — never write it.
- [ ] Read AND write the user's **private** 1Password vault (`my.1password.eu`) via `op`
  for anything omf needs (writes may biometric-prompt once per op session).
- [ ] NEVER touch the work vault (`istase.1password.eu`) for private routes.
- [ ] Per-child env allowlist keyed by account + op-account; `zeroize` after env build;
  status prints names only; no-op fallback = cache-only then refuse (no plaintext).

## 8. Exec model (mode-dispatched)

- [ ] Interactive → `syscall.Exec` replace (build scrubbed env + assert routing, hand off).
- [ ] Local-LLM → stay-in-tree supervisor (omf IS the safety mechanism).
- [ ] One-shot `-p` → wrapped subprocess so the argv secret-scan runs.

## 9. TUI + emacs control plane

- [ ] `omf tui` — tmux-native orchestration surface: agent panes + a composer pane.
- [ ] `omf compose` — open `emacsclient -c` (or `emacs -q -nw`) on a `~/tmp` buffer with
  forge-prompt-like keybinds (minor mode), return contents as the prompt/dispatch target.
- [ ] forge-as-driver: a primitive forge can call to spawn claude/codex or omc/omx into a
  sub-pane of forge's own tmux session.

## 10. v1 scope (the compiled safety floor + discovery skeleton)

- [ ] `omf/` Cargo + Go workspace in-repo; `just` recipes (`go build/test`,
  `cargo build/test/clippy`) folded under the existing `just ci` gate.
- [ ] Go dispatcher: manifest load + clamp + `omf.toml` schema; `omf <profile>` routes to
  the right `FORGE_CONFIG` (exec-replace); `omf resume`/`omf hist` call existing bash.
- [ ] Compiled work≠private routing + unit test (a work command can never resolve a
  private home).
- [ ] `omf-core` (Rust): admission preflight + single-flight + MLX caps; `omf-core secrets`
  read keychain + read/write private vault + env allowlist.
- [ ] `omf llm`: discover + list llama-swap/ollama models; load/unload; refuse over-budget.
  See §6's pointer to `local-forge.bash` — reuse its discovery pattern, don't re-derive it.
- [ ] `omf doctor`: manifest validation + backend discovery + profile creds + dep tiers.

Success criteria: unit test proves work↛private; over-budget model launch refused (a
fits-model admitted); keychain read never writes; child env = allowlisted names only;
`just ci` green.

## 11. Roadmap

- [ ] P1: watchdog; full llama-swap/ollama/mlx unified lifecycle; GGUF default coder;
  Python registrar; argv secret-scan.
- [ ] P2: tmux orchestration (forge-as-driver, interop panes); forge-zsh-config TUI;
  `omf compose` emacs buffer input.
- [ ] P3: plan/subscription switching UI; prompt-scan classifier; breadth
  (gemini/copilot/crush/aider as backends); full `omf tui` control plane; emacs features.

## 11a. Backlog — added 2026-06-15 (user)

- [ ] `--madmax` and `--yolo` global flags (danger/auto-approve modes; mirror
  the omc/omx semantics — `--madmax` = max-autonomy run, `--yolo` = skip
  confirmations). Must respect the compiled safety floor (§5) — these flags
  may loosen UX gates but NEVER the work≠private routing or secrets invariants.
- [ ] omf as meta-wrapper and top-level orchestrator FOR omc and omx (not just
  alongside them): omf becomes the primus-inter-pares front that drives omc and
  omx as managed backends (spawn, route, supervise), consistent with the
  forge-as-driver primitive in §9.
- [ ] Close the feature gap: omf is currently hollow. The structure/architecture
  is good and the existing features justify the tool, but omf is missing the
  CORE functions and commands that make omc and omx actually useful — these are
  not optional niceties, they are table stakes. Inventory every core omc/omx
  command and ensure omf has a discovery+passthrough (or first-class) equivalent.
  (User: "more details soon. remind me pls." → REMINDER OWED to user.)
- [ ] Define broad omf command categories — and possibly application domains —
  as the top-level taxonomy the CLI/TUI is organized around (orchestration,
  routing, llm, secrets, doctor, compose, …). Decide categories before adding
  the gap-filling commands above so they land in a coherent surface.

## 12. Top risks

1. Doomed-abstraction treadmill (omf lags omc/omx/forge as they drift). Mitigation:
   transparent passthrough + discovery, never reimplement subcommands; `doctor` reports
   versions; the core knows no upstream flag sets.
2. Scope sprawl → half-built, less safe than the zsh it replaces. Mitigation: ship the
   compiled floor first; keep shelling out to proven snippets; never delete a working
   snippet until its replacement passes the same scenarios.
3. False safety on MLX (RULE 0). Mitigation: refuse-before-launch is the advertised
   guarantee; watchdog is a backstop; default to pageable GGUF.

## 13. Decisions (resolved)

- Languages: Go + Rust + Bash + Python/uv (not limited; add as justified). ✓
- Location: in-repo, everything (agents/helpers/tooling/hooks + the omf CLI/TUI). ✓
- Secrets: omf reads cache hands-off + reads/writes the private 1P vault via op. ✓
- Root `iogpu` cap: not needed for v1. ✓
- MLX: omf steers qwen36-mlx → GGUF/pageable and refuses unsafe direct loads. ✓ (pending user ack)
