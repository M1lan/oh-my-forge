//! omf-core CLI entrypoint: argv subcommand dispatch.
//!
//! Usage:
//!   omf-core secrets <...>   -- secrets subsystem (F2)
//!   omf-core guard   <...>   -- memory-guard subsystem (F3)
//!
//! Scaffold behaviour: subcommands are recognised and routed but report
//! "not yet implemented" until F2/F3 land. Unknown subcommands -> USAGE.

use std::process::ExitCode;

use omf_core::{exit, guard, secrets};

fn usage() {
    eprintln!(
        "omf-core -- compiled security floor\n\
         \n\
         usage:\n\
         \x20 omf-core secrets <subcommand> [args]\n\
         \x20 omf-core guard   <subcommand> [args]\n"
    );
}

fn main() -> ExitCode {
    let mut args = std::env::args().skip(1);
    let code = match args.next().as_deref() {
        Some("secrets") => secrets::run(args.collect()),
        Some("guard") => guard::run(args.collect()),
        Some("-h") | Some("--help") | Some("help") => {
            usage();
            exit::OK
        }
        Some(other) => {
            eprintln!("omf-core: unknown subcommand: {other}");
            usage();
            exit::USAGE
        }
        None => {
            usage();
            exit::USAGE
        }
    };
    ExitCode::from(code as u8)
}
