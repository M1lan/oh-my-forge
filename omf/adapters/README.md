# omf/adapters — bash launchers over the tuned zsh TUIs

`omf resume` and `omf hist` do **not** reimplement forge's pickers. They reuse
the user's already-tuned zsh functions **verbatim**, vendored under `vendor/`.
The bash entrypoints are thin launchers: source the vendored snippet in a clean
`zsh -f` and hand off to the function.

| omf subcommand | entrypoint        | reused function | vendored snippet                         |
| -------------- | ----------------- | --------------- | ---------------------------------------- |
| `omf resume`   | `resume.bash`     | `fcr`           | `vendor/forge-conversation-resume.zsh`   |
| `omf hist`     | `hist.bash`       | `forge-hist`    | `vendor/forge-history.zsh`               |

## Verbatim policy

`vendor/*.zsh` are **byte-identical** copies of the canonical snippets:

```bash
# canonical source of record:
~/.config/mein-zsh/snippets/forge-conversation-resume.zsh   # defines fcr
~/.config/mein-zsh/snippets/forge-history.zsh               # defines forge-hist

# re-vendor (and verify identical) if the canonical snippets change:
cp -p ~/.config/mein-zsh/snippets/forge-conversation-resume.zsh vendor/
cp -p ~/.config/mein-zsh/snippets/forge-history.zsh             vendor/
cmp ~/.config/mein-zsh/snippets/forge-conversation-resume.zsh vendor/forge-conversation-resume.zsh
cmp ~/.config/mein-zsh/snippets/forge-history.zsh             vendor/forge-history.zsh
```

Do not edit the files in `vendor/` — improvements go to the canonical snippet,
then get re-vendored. To run against the canonical copy instead of the vendored
one, set `OMF_FCR_SNIPPET` / `OMF_FORGE_HIST_SNIPPET`.

## Contract for the Go dispatcher

`omf resume` → `exec omf/adapters/resume.bash` (interactive picker; execs `forge`).
`omf hist` → `exec omf/adapters/hist.bash "$@"` (args forwarded to `forge-hist`:
`-a|--all`, `-n COUNT`, `PATTERN`). Both are passthrough — never reimplemented.

`zsh` is a runtime dependency of these two adapters (the pickers are zsh).
