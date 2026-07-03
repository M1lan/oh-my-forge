# erc-llmd-prefer.el — prefer the external daemon, embed only as fallback

`erc-llmd-prefer.el` adds **one command** that picks the right partyline
backend automatically:

- If an **external `erc-llmd` daemon** is already serving the AF_UNIX socket,
  ERC connects to it as a **pure client** (the partyline outlives Emacs).
- Otherwise it falls back to the **embedded P0 pseudo-ircd** via `llm-erc`
  (Emacs becomes the server).

It is purely additive: it does not modify `llm-erc.el`, `erc-llmd.el`, or any
live state. It reuses the existing `erc-llmd--connect` connect-function idiom
(by delegating to `erc-llmd-connect`). No `--eval` inlining, no JSON, AF_UNIX
only.

## Opt-in

Add this to your init (load the two client shims first, then the preferer):

```elisp
(add-to-list 'load-path "/Users/milan.santosi/mysrc/oh-my-workbench/oh-my-forge/erc-llmd/elisp")
(require 'erc-llmd)         ; external-daemon client (erc-llmd-connect)
(require 'erc-llmd-prefer)  ; this file
;; optional key:
(global-set-key (kbd "C-c L") #'erc-llmd-prefer-llm-erc)
```

Then just `M-x erc-llmd-prefer-llm-erc`. A prefix arg (`C-u`) prompts for the
socket path.

The embedded fallback additionally needs `llm-erc` on `load-path` (the live
`~/.emacs.d/lisp/ai/erc-llm/` tree). When the daemon is up the command works
without `llm-erc`; it only errors — clearly — if it must fall back and
`llm-erc` is unavailable.

## Custom variables

| Variable                          | Default                               | Purpose |
|-----------------------------------|---------------------------------------|---------|
| `erc-llmd-prefer-socket-path`     | `~/.local/state/erc-llm/ircd.sock`    | Socket to probe / prefer. Mirrors `erc-llmd-socket-path`. |
| `erc-llmd-prefer-probe-timeout`   | `0.5`                                 | Seconds to wait for the non-blocking listener probe to settle. |

## Detection heuristic

`erc-llmd-prefer-external-daemon-p` returns non-nil iff **both**:

1. **The path is a live AF_UNIX listener** — not merely an existing file.
   Tested by opening a non-blocking AF_UNIX *client* connection
   (`erc-llmd-prefer--live-listener-p`): a live listener reaches process
   status `open`; a stale leftover socket file refuses with ECONNREFUSED
   (status `failed`); a missing path errors. The probe connection is always
   deleted before returning.
2. **It is not this Emacs's embedded ircd** — if `erc-llm-ircd-running-p` is
   loaded and returns non-nil, this Emacs is the server, so it is not
   "external." When that feature is not loaded, a live listener can only be
   foreign.

### Limitations (be honest)

- **Not a cryptographic identity check.** It detects "a live listener that is
  not *this* Emacs's embedded ircd." Any compatible listener on that path
  (the Rust `erc-llmd`, another Emacs running `llm-erc`, etc.) reads as
  "external." That is the correct question for "should I start my own server
  or just connect?" — but it assumes the listener speaks the same wire
  protocol. A foreign non-`erc-llmd` listener squatting on that exact path
  would be mis-detected (out of scope; the path is ours by convention).
- **TOCTOU race.** Detection and the subsequent connect are separate syscalls.
  A daemon can die or start in the gap, so a "prefer external" decision can
  still hit a refused connect, and a "fall back to embedded" decision can race
  a daemon that comes up a moment later (then `erc-llm-ircd-start` would find
  the path in use). A single Emacs process cannot hold a lock across both
  steps. The window is small but real; the delegated commands surface the
  error rather than hiding it.
- **The probe is a real, if instantaneous, connection.** On a live daemon it
  briefly appears and disappears as a client — harmless, but not literally
  zero-observable.

## Verifying

```bash
CRATE=/Users/milan.santosi/mysrc/oh-my-workbench/oh-my-forge/erc-llmd

# byte-compile clean (sibling erc-llmd.el must be on load-path):
emacs -Q --batch -L "$CRATE/elisp" -f batch-byte-compile "$CRATE/elisp/erc-llmd-prefer.el"
rm -f "$CRATE/elisp/erc-llmd-prefer.elc"

# detection on a THROWAWAY socket (never the real one):
TESTSOCK=/tmp/erc-llmd-prefer-test.sock
"$CRATE/target/release/erc-llmd" serve --socket "$TESTSOCK" &
emacs -Q --batch -L "$CRATE/elisp" -l "$CRATE/elisp/erc-llmd-prefer.el" \
  --eval "(princ (format \"%S\n\" (erc-llmd-prefer-external-daemon-p \"$TESTSOCK\")))"  # => t
kill %1; rm -f "$TESTSOCK"
```
