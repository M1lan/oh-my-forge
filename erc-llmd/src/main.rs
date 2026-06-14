//! erc-llmd -- standalone AF_UNIX pseudo-ircd.
//!
//! A drop-in replacement for the Emacs-resident `erc-llm-ircd`: it speaks the
//! exact same wire protocol over the same kind of Unix-domain socket, so the
//! live `partyline` Bash client and ERC connect unchanged, and the partyline
//! survives the death of Emacs.
//!
//! Usage:
//!   erc-llmd serve [--socket <path>] [--server-name <name>] [--channel <#name>]
//!   erc-llmd toon dec [--lenient]   # read TOON on stdin, write canonical TOON
//!   erc-llmd toon enc [--delimiter comma|tab|pipe] [--indent N] [--fold]
//!
//! Defaults: socket `~/.local/state/erc-llm/ircd.sock`, server `erc-llm.local`,
//! channel `#partyline`. The socket path can also come from `$ERC_LLM_SOCK`.
//!
//! Security: AF_UNIX only (nothing reachable off-box). Socket dir created 0700,
//! socket file chmod 0600 after bind, stale socket removed on start. No JSON,
//! no eval, no shell-out; defensive parsing with length caps.
//!
//! TOON CLI design (intentionally thin — the library is the real deliverable).
//! "No JSON on the wire" means the CLI keeps TOON as both input and output.
//! `toon dec` parses TOON from stdin into the in-memory `Value` and writes it
//! back as canonical TOON (a strict round-trip / normalizer); decode errors are
//! reported on stderr with a non-zero exit. `toon enc` likewise reads TOON and
//! re-emits canonical TOON, honoring the `--delimiter`, `--indent`, and
//! `--fold` (key-folding) encoder options. Both directions therefore share a
//! TOON wire format; the JSON-to-`Value` mapping lives only in the test harness
//! (a dev-only `serde_json` dependency) so the shipped binary stays
//! dependency-free.

use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use erc_llmd::server::Config;
use erc_llmd::toon::{decode, encode, Delimiter, EncodeOptions, KeyFolding};
use erc_llmd::{bind_listener, new_state, run_accept_loop};

fn default_socket_path() -> PathBuf {
    if let Ok(env) = std::env::var("ERC_LLM_SOCK") {
        if !env.is_empty() {
            return PathBuf::from(env);
        }
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    Path::new(&home)
        .join(".local/state/erc-llm")
        .join("ircd.sock")
}

struct Args {
    socket: PathBuf,
    server_name: String,
    channel: String,
}

fn parse_serve_args(argv: &mut impl Iterator<Item = String>) -> Result<Args, String> {
    let mut socket = default_socket_path();
    let mut server_name = "erc-llm.local".to_string();
    let mut channel = "#partyline".to_string();

    while let Some(flag) = argv.next() {
        match flag.as_str() {
            "--socket" => {
                socket = PathBuf::from(
                    argv.next()
                        .ok_or_else(|| "--socket requires a value".to_string())?,
                );
            }
            "--server-name" => {
                server_name = argv
                    .next()
                    .ok_or_else(|| "--server-name requires a value".to_string())?;
            }
            "--channel" => {
                channel = argv
                    .next()
                    .ok_or_else(|| "--channel requires a value".to_string())?;
            }
            other => return Err(format!("unknown flag: {other}")),
        }
    }

    Ok(Args {
        socket,
        server_name,
        channel,
    })
}

fn usage() {
    eprintln!(
        "erc-llmd -- standalone AF_UNIX pseudo-ircd + TOON codec\n\
         \n\
         USAGE:\n\
         \x20   erc-llmd serve [--socket <path>] [--server-name <name>] [--channel <#name>]\n\
         \x20   erc-llmd toon dec [--lenient]\n\
         \x20   erc-llmd toon enc [--delimiter comma|tab|pipe] [--indent N] [--fold]\n\
         \n\
         Defaults: socket ~/.local/state/erc-llm/ircd.sock (or $ERC_LLM_SOCK),\n\
         \x20         server-name erc-llm.local, channel #partyline\n\
         \n\
         TOON: `dec`/`enc` both read TOON on stdin and write canonical TOON on\n\
         stdout (no JSON on the wire). `dec` is a strict round-trip/validator;\n\
         `enc` re-emits with the chosen encoder options."
    );
}

fn run_serve(argv: &mut impl Iterator<Item = String>) -> Result<(), String> {
    let args = parse_serve_args(argv).inspect_err(|_| usage())?;

    let cfg = Config {
        server_name: args.server_name,
        default_channel: args.channel,
        max_line_bytes: 8192,
    };

    let listener =
        bind_listener(&args.socket).map_err(|e| format!("bind {}: {e}", args.socket.display()))?;

    eprintln!("erc-llmd: listening on {}", args.socket.display());

    let state = new_state(cfg);
    run_accept_loop(listener, state);

    Ok(())
}

fn read_stdin() -> Result<String, String> {
    let mut buf = String::new();
    std::io::stdin()
        .read_to_string(&mut buf)
        .map_err(|e| format!("read stdin: {e}"))?;
    Ok(buf)
}

fn run_toon(argv: &mut impl Iterator<Item = String>) -> Result<(), String> {
    let dir = match argv.next() {
        Some(s) => s,
        None => return Err("missing toon direction (expected `dec` or `enc`)".to_string()),
    };
    match dir.as_str() {
        "dec" => {
            let mut strict = true;
            for flag in argv.by_ref() {
                match flag.as_str() {
                    "--lenient" => strict = false,
                    "--strict" => strict = true,
                    other => return Err(format!("unknown flag: {other}")),
                }
            }
            let input = read_stdin()?;
            let value = decode(&input, strict).map_err(|e| format!("decode: {e}"))?;
            let out = encode(&value, &EncodeOptions::default());
            println!("{out}");
            Ok(())
        }
        "enc" => {
            let mut opts = EncodeOptions::default();
            while let Some(flag) = argv.next() {
                match flag.as_str() {
                    "--delimiter" => {
                        let v = argv
                            .next()
                            .ok_or_else(|| "--delimiter requires a value".to_string())?;
                        opts.delimiter = match v.as_str() {
                            "comma" | "," => Delimiter::Comma,
                            "tab" | "\t" => Delimiter::Tab,
                            "pipe" | "|" => Delimiter::Pipe,
                            other => return Err(format!("unknown delimiter: {other}")),
                        };
                    }
                    "--indent" => {
                        let v = argv
                            .next()
                            .ok_or_else(|| "--indent requires a value".to_string())?;
                        opts.indent = v.parse().map_err(|_| format!("invalid --indent: {v}"))?;
                    }
                    "--fold" => opts.key_folding = KeyFolding::Safe,
                    other => return Err(format!("unknown flag: {other}")),
                }
            }
            // `enc` reads TOON (no JSON on the wire) and re-emits canonical TOON.
            let input = read_stdin()?;
            let value = decode(&input, true).map_err(|e| format!("parse input: {e}"))?;
            let out = encode(&value, &opts);
            println!("{out}");
            Ok(())
        }
        other => Err(format!(
            "unknown toon direction: {other} (expected `dec`|`enc`)"
        )),
    }
}

fn run() -> Result<(), String> {
    let mut argv = std::env::args().skip(1);
    let sub = match argv.next() {
        Some(s) => s,
        None => {
            usage();
            return Err("missing subcommand (expected `serve` or `toon`)".to_string());
        }
    };
    match sub.as_str() {
        "serve" => run_serve(&mut argv),
        "toon" => run_toon(&mut argv),
        other => {
            usage();
            Err(format!(
                "unknown subcommand: {other} (expected `serve` or `toon`)"
            ))
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("erc-llmd: error: {e}");
            ExitCode::FAILURE
        }
    }
}
