# erc-llmd

A standalone, localhost-only pseudo-IRC daemon written in Rust. It is a
**drop-in replacement** for the Emacs-resident `erc-llm-ircd` (see
`~/.emacs.d/lisp/ai/erc-llm/erc-llm-ircd.el`): it speaks the exact same wire
protocol over the same kind of AF_UNIX socket, so the live `partyline` Bash
client and ERC connect **unchanged** — and the partyline now **survives the
death of Emacs**, because the server is an out-of-process daemon.

This is the "omf half" of a two-halves system. This slice is **real clients
only**: there are no virtual participants, no inject hook, and no control-plane
(`ctl.sock`/registry/router/ABORT). Every channel member is a live socket
client (the `partyline` client makes one-shot agents into real clients).

## Security posture

- **AF_UNIX only.** Nothing is reachable off-box; there is no TCP listener.
- Socket directory created `0700`; the socket file is `chmod 0600` after bind.
- A stale socket file from a prior run is removed on start.
- No JSON anywhere, no `eval`, no shell-out. Defensive parsing with length
  caps (inbound lines over 8192 bytes are dropped, the connection is kept).
- Zero runtime dependencies: `std`-only, thread-per-connection +
  `Arc<Mutex<ServerState>>`.

## Build

```bash
cd ~/mysrc/oh-my-workbench/oh-my-forge/erc-llmd
cargo build --release
# binary at ./target/release/erc-llmd
```

## Run

```bash
# default socket: ~/.local/state/erc-llm/ircd.sock (or $ERC_LLM_SOCK)
erc-llmd serve

# explicit test socket (never collide with the live one):
erc-llmd serve --socket /tmp/erc-llmd-selftest.sock
```

Flags:

| Flag             | Default                              | Meaning                          |
|------------------|--------------------------------------|----------------------------------|
| `--socket`       | `$ERC_LLM_SOCK` or the canonical path| AF_UNIX socket path to listen on |
| `--server-name`  | `erc-llm.local`                      | name in numerics + prefixes      |
| `--channel`      | `#partyline`                         | the default channel created      |

The canonical default socket path is `~/.local/state/erc-llm/ircd.sock`. The
`$ERC_LLM_SOCK` environment variable overrides it (and `--socket` overrides
that).

## Connect from the `partyline` Bash client

The real `partyline` client connects unchanged — point it at the daemon's
socket with `ERC_LLM_SOCK`:

```bash
# in one place: start the daemon on a test socket
erc-llmd serve --socket /tmp/erc-llmd-selftest.sock

# in agents / other shells: drive the partyline against that socket
export ERC_LLM_SOCK=/tmp/erc-llmd-selftest.sock
~/.emacs.d/.agent/partyline up alpha          # connect+register+JOIN (run detached)
~/.emacs.d/.agent/partyline up beta           # a second client
~/.emacs.d/.agent/partyline say  alpha 'hello from alpha'
~/.emacs.d/.agent/partyline read beta 20      # beta sees alpha's JOIN + PRIVMSG
~/.emacs.d/.agent/partyline down alpha
~/.emacs.d/.agent/partyline down beta
```

## Connect from ERC (Emacs)

Load the companion Elisp file (never inline `--eval`) and run the interactive
command. Unlike the embedded `llm-erc.el`, this file does **not** start any
server — it assumes `erc-llmd` already owns the socket:

```bash
emacs -q -l ~/mysrc/oh-my-workbench/oh-my-forge/erc-llmd/elisp/erc-llmd.el
```

then inside Emacs:

```
M-x erc-llmd-connect          ;; dials erc-llmd-socket-path, JOINs #partyline
C-u M-x erc-llmd-connect      ;; prompt for a socket path
```

Customize `erc-llmd-socket-path` (defaults to `$ERC_LLM_SOCK` or the canonical
path), `erc-llmd-server-name`, `erc-llmd-default-channel`, and `erc-llmd-nick`.

## Wire protocol

The protocol is replicated from `erc-llm-ircd.el` and is intentionally minimal:

- Registration completes when `NICK` and `USER` are both present and the client
  is not mid-`CAP` negotiation; on completion the daemon sends numerics
  `001 002 003 004 005 375 372 376`.
- Message source prefix is `nick!nick@localhost`.
- Numerics are formatted `:erc-llm.local NNN <target-or-*> <text>`.
- Supported commands: `CAP` (`LS`/`REQ`→NAK/`LIST`/`END`), `NICK`, `USER`,
  `PING`, `PONG`, `JOIN`, `PART`, `PRIVMSG`, `NOTICE`, `MODE` (channel query →
  `324 <chan> +nt`), `WHO`, `NAMES`, `TOPIC`, `QUIT`.
- No-ops: `WHOIS`, `USERHOST`, `ISON`, `LIST`, `LUSERS`, `AWAY`.
- An unknown command from a registered client gets numeric `421`.

## Tests

```bash
cargo test
```

- **Parser unit tests** (`src/parser.rs`): prefix/command/params/trailing edge
  cases, CR/LF stripping, empty-trailing, whole-remainder-trailing, repeated
  space collapsing.
- **Integration test** (`tests/two_client_broadcast.rs`): opens two AF_UNIX
  clients to a temp-socket server, registers + JOINs both, and asserts that a
  channel `PRIVMSG` from one reaches the other and that the JOIN is seen (and
  that the sender does **not** receive an echo of its own channel message).

## Relationship to the omf workspace

This crate is **purely additive** and deliberately **not** a member of the
inner `omf/Cargo.toml` workspace (that file is fenced as the FORGE lane). Its
own `Cargo.toml` declares an empty `[workspace]` table so it is an independent
workspace root and cargo never attaches it to any ancestor workspace.
