---
name: urgent-reminder
description: Draw the operator's physical attention to a terminal with an audio chime, a spoken TTS reminder, and an escalating Ghostty colour alarm (calm-yellow through orange to ALARMING RED, flashing). Use when something rare and important needs the operator to look up NOW -- a long job finished, a destructive gate awaits a decision, or a context-specific trigger fired. Backed by two reusable Bash helpers on PATH in agent sessions: agent-remind.bash and ghostty-alert.bash.
---

# urgent-reminder

The team's "make the human look up" primitive. Three escalating channels:
audio chime, spoken voice, and a Ghostty window that visibly alarms by colour.
Use sparingly -- a reminder that fires often trains the operator to ignore it.

## Helpers (on PATH in any agent Bash session)

Both live in `~/.config/sh/bin/` and are added to PATH by
`agent-bash-env.bash`. Invoke by bare name from a Bash hook or the `shell`
tool (wrap shell-tool calls in `/opt/homebrew/bin/bash -c '...'`).

### agent-remind.bash -- chime + spoken reminder

```bash
agent-remind.bash "Build is green. 412 tests passed."
agent-remind.bash --sound Funk --voice Daniel "Deploy needs your approval."
agent-remind.bash --ghostty "Look at THIS window."   # also flash the tty
agent-remind.bash --no-tts --sound Glass "ping"        # chime only
```

- Non-blocking: detaches the chime+speech so a hook never stalls on audio.
- `--sound` takes a `/System/Library/Sounds` name (Sosumi, Funk, Glass,
  Ping, Hero, Basso...) or an absolute path. `--voice` is any `say` voice.
- `--ghostty` also starts the colour alarm on the resolved tty.
- Env defaults: `AGENT_REMIND_SOUND`, `AGENT_REMIND_VOICE`.

### ghostty-alert.bash -- escalating colour alarm

```bash
ghostty-alert.bash start                      # alarm the current tty, 120s cap
ghostty-alert.bash start --tty /dev/ttys012 --max 60
ghostty-alert.bash once                        # one quick foreground burst (test)
ghostty-alert.bash status
ghostty-alert.bash stop                        # restore the window
```

- Mechanism: writes OSC 11 ("set background") escapes straight to the target
  pty, walking a palette from calm-yellow through orange to ALARMING RED,
  flashing to black between beats and ringing the bell. Flashes faster as it
  climbs. tput cannot emit OSC 11, so the raw escapes are deliberate.
- Targeting: `--tty` wins, else `$GHOSTTY_ALERT_TTY`, else the caller's `tty`.
  To alarm a DIFFERENT window than the one you run in, pass its `--tty`
  (find it by running `tty` inside that window).
- Self-bounds at `--max` seconds (default 120) so it never runs forever.
  Retire early with `ghostty-alert.bash stop`, which kills the loop and
  restores the configured background (read from `~/.config/ghostty/config`,
  default `#001a00`).

## How to wire a NEW trigger (the reusable pattern)

This is the shape the Capy detector uses; copy it for any rare alert:

1. Drop a hook in `~/.config/sh/agent-hooks.d/NN-<name>.bash`.
2. Write a cheap pure-Bash signal matcher against the just-run `${cmd}`.
   Be conservative -- false alarms are worse than misses.
3. Register it in `__agent_always_hooks` (deterministic) for can't-miss
   alerts, or `__agent_occasional_hooks` (~1/1024 sampled) for soft probes.
4. On a deduped hit: write a marker file under `${AGENT_STATE_DIR}` (so the
   LLM side notices), then call `agent-remind.bash --ghostty "<spoken text>"`.
5. Have the matching skill read the marker, do the work, then
   `ghostty-alert.bash stop` + remove the marker.

Re-entrancy: always-hooks run under `functrace`; the dispatcher guards with
`__agent_in_hook` so a matcher cannot re-fire on its own source text. Keep
matchers and markers cheap and idempotent.

## When NOT to use

Routine progress, anything the operator is already watching, or anything that
would fire more than a few times a day. This is for the rare look-up-NOW
moment only.
