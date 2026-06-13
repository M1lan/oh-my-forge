# Cockpit zero-decoration visual spec

Owner: OMX design/aesthetics. Implementers: OMC for launcher and Emacs wiring.
Scope: `omf` cockpit tmux panes and the forge-prompt input buffer.

## Design intent

The cockpit is an operator surface, not a dashboard. It should feel like raw
terminal glass: useful process output and a prompt composer, with no chrome that
competes for attention. If an element is not typed by an agent, emitted by a
command, or required to enter a prompt, it is decoration and must be removed.

## Hard rules

1. **No titles or badges.** Do not show pane names, agent labels, prompt labels,
   role chips, powerline segments, HUD text, or status widgets in the cockpit.
2. **No tmux status chrome.** The cockpit window must not display a tmux status
   bar, pane-border-status, or pane-border-format labels.
3. **No ornamental borders.** Avoid visible decorative borders. If tmux needs a
   separator for geometry, it must be visually quiet: no title text, no accent
   colors, no active-pane highlight, and no extra padding around labels.
4. **No Emacs chrome in the input pane.** The input buffer must hide mode-line,
   header-line, tab-line, fringe, line numbers, scroll bars, toolbar/menu chrome,
   fill-column indicators, and any prompt-archive/status messages that are not
   direct user text.
5. **Raw text only.** The Emacs input pane should show the prompt body and cursor.
   Syntax highlighting, icons, emojis, decorative faces, and background blocks are
   out of scope for the default cockpit.
6. **Monochrome by default.** Use terminal default foreground/background for the
   cockpit structure. Colors emitted by agent TUIs remain their own content, but
   the cockpit shell must not add colors.
7. **Stable geometry over adornment.** The bottom composer stays a compact text
   strip. Do not spend vertical space on labels; use height for editable text.

## tmux implementation target

OMC should make launcher panes satisfy these observable tmux settings or their
nearest tmux-version equivalent:

- `status off`
- `pane-border-status off`
- empty `pane-border-format`
- `pane-border-style` and `pane-active-border-style` use default/low-contrast
  colors with no active accent
- no pane title text visible after boot
- no scripted `printf` banner remains visible once the cockpit is ready

The current `scripts/omf-orchestra.sh` lines that set `pane-border-status top`
and `pane-border-format ' #{pane_title} '` violate this spec.

## Emacs input implementation target

OMC should make the cockpit input buffer buffer-local and reversible. The user's
normal in-Emacs `forge-prompt` buffers must keep their existing appearance and
keybindings.

Required buffer-local visual state for the cockpit input buffer:

- `mode-line-format` nil
- `header-line-format` nil
- `tab-line-format` nil where applicable
- no line numbers or relative line numbers
- no fringes in the cockpit input window
- no scroll bars in the cockpit input window
- no hl-line, fill-column indicator, or visual guides
- default face/background only; no cockpit-specific color faces
- one visible cursor; no extra prompt prefix text

## Acceptance checks

A cockpit implementation passes this spec when all checks are true:

1. A screenshot of the full cockpit has no tmux pane titles, no status bar, no
   powerline/HUD strip, and no decorative border labels.
2. `tmux show-options` / `show-window-options` for the session reports status and
   pane-border-status disabled, with no non-empty pane-border-format.
3. The Emacs input window shows only editable prompt text and cursor; mode-line,
   header-line, fringe, scrollbars, and line numbers are absent.
4. Stock non-cockpit `forge-prompt` behavior remains unchanged.
5. The zero-decoration default does not implement the deferred live-introspection
   top strip; that belongs to `omf-pww` and must remain opt-in/deferred.

## Non-goals

- Do not implement the live-introspection top strip here.
- Do not redesign agent TUI internals.
- Do not modify user-global Emacs appearance.
- Do not add decorative minimalism such as branded separators, icons, or labels.
