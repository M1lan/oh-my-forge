//! Memory-guard subsystem (F3 / omf-bfl).
//!
//! A LIGHT backstop, not the primary defence. The real freeze prevention is
//! the MLX wired/pageable split applied by the `mlx_lm_server_safe` wrapper
//! (OMX's `omf llm mlx`); this module only:
//!   * surfaces the proven MLX cap constants so `omf doctor` can verify them;
//!   * gives an admission decision (admit / warn / refuse) -- and for MLX it
//!     NEVER refuses, because the model stays pageable (worst case is a slow
//!     request, never a dead machine, RULE 0 / plan 6);
//!   * provides a single-flight `flock` so two heavy runs can't overlap
//!     (belt-and-braces with llama-swap's own `exclusive`).
//!
//! The MLX caps are the floor's source of truth; the manifest (omf.toml) may
//! only request STRICTER values -- `manifest::Limits::clamp_to_floor` enforces
//! that against these constants.

use std::fs::OpenOptions;
use std::os::unix::io::AsRawFd;
use std::path::Path;

use crate::exit;

/// MLX wired-memory pin, in GiB. At most this is pinned; the remainder of
/// the model stays pageable so the OS can always reclaim pages.
pub const MLX_WIRED_LIMIT_GIB: u64 = 14;
/// MLX allocator ceiling, in GiB. The allocator errors near this cap rather
/// than at MLX's ~27 GiB default.
pub const MLX_MEMORY_LIMIT_GIB: u64 = 18;
/// MLX cache ceiling, in GiB. Freed buffers above this return to the OS.
pub const MLX_CACHE_LIMIT_GIB: u64 = 2;

/// Admission verdict for a requested allocation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Admission {
    /// Fits within budget.
    Admit,
    /// Over budget but allowed to proceed (MLX stays pageable).
    Warn(String),
    /// Over budget and refused (non-MLX path).
    Refuse(String),
}

/// Decide admission for a requested `peak_gib` against `budget_gib`.
///
/// MLX never refuses (light backstop): an over-budget MLX request degrades
/// to a slow/failed request, not a dead machine. Non-MLX over-budget is
/// refused so a hard allocation can't wedge the box.
#[must_use]
pub fn admit(peak_gib: u64, budget_gib: u64, is_mlx: bool) -> Admission {
    if peak_gib <= budget_gib {
        return Admission::Admit;
    }
    let msg = format!("peak {peak_gib} GiB exceeds budget {budget_gib} GiB");
    if is_mlx {
        Admission::Warn(format!("{msg}; MLX stays pageable, proceeding (backstop)"))
    } else {
        Admission::Refuse(msg)
    }
}

/// A held single-flight lock. Dropping it (closing the fd) releases the lock.
pub struct SingleFlight {
    _file: std::fs::File,
}

/// Try to acquire an exclusive, non-blocking advisory lock on `path`.
/// Returns `Ok(None)` when the lock is already held by another process,
/// `Ok(Some(guard))` when acquired, and `Err` on an I/O failure.
pub fn try_single_flight(path: &Path) -> std::io::Result<Option<SingleFlight>> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    // The lock file is a pure flock target and carries no content, so we
    // neither truncate nor append — keep whatever is there (nothing).
    let file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(false)
        .open(path)?;
    // SAFETY: flock on a valid open fd; the fd outlives the call via `file`.
    let rc = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
    if rc == 0 {
        Ok(Some(SingleFlight { _file: file }))
    } else {
        let err = std::io::Error::last_os_error();
        // EWOULDBLOCK == EAGAIN on macOS/Linux, but they are distinct symbols
        // and may differ on other platforms; treat either as "contended". A
        // runtime comparison avoids a duplicate-match-arm error where equal.
        let code = err.raw_os_error();
        if code == Some(libc::EWOULDBLOCK) || code == Some(libc::EAGAIN) {
            Ok(None) // contended
        } else {
            Err(err)
        }
    }
}

/// Default single-flight lock path: `$XDG_CACHE_HOME/omf/runtime.lock` or
/// `~/.cache/omf/runtime.lock`.
fn default_lock_path() -> std::path::PathBuf {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| std::path::PathBuf::from(h).join(".cache")))
        .unwrap_or_else(|| std::path::PathBuf::from("."));
    base.join("omf").join("runtime.lock")
}

// --- CLI -------------------------------------------------------------------

fn arg_value<'a>(args: &'a [String], flag: &str) -> Option<&'a str> {
    args.iter()
        .position(|a| a == flag)
        .and_then(|i| args.get(i + 1))
        .map(String::as_str)
}

/// `guard caps` -- print the MLX cap constants for `omf doctor` to verify.
fn cmd_caps() -> i32 {
    println!("wired_gib={MLX_WIRED_LIMIT_GIB}");
    println!("memory_gib={MLX_MEMORY_LIMIT_GIB}");
    println!("cache_gib={MLX_CACHE_LIMIT_GIB}");
    exit::OK
}

/// `guard admit --peak <gib> --budget <gib> [--mlx]` -- admission decision.
fn cmd_admit(args: &[String]) -> i32 {
    let peak: u64 = match arg_value(args, "--peak").and_then(|s| s.parse().ok()) {
        Some(v) => v,
        None => {
            eprintln!("omf-core guard admit: --peak <gib> is required");
            return exit::USAGE;
        }
    };
    let budget: u64 = match arg_value(args, "--budget").and_then(|s| s.parse().ok()) {
        Some(v) => v,
        None => {
            eprintln!("omf-core guard admit: --budget <gib> is required");
            return exit::USAGE;
        }
    };
    let is_mlx = args.iter().any(|a| a == "--mlx");
    match admit(peak, budget, is_mlx) {
        Admission::Admit => {
            println!("admit");
            exit::OK
        }
        Admission::Warn(why) => {
            eprintln!("warn: {why}");
            println!("admit");
            exit::OK
        }
        Admission::Refuse(why) => {
            eprintln!("refuse: {why}");
            exit::REFUSED
        }
    }
}

/// `guard lock [--path P]` -- try the single-flight lock once, non-blocking.
/// Exit OK if free/acquired, REFUSED if already held.
fn cmd_lock(args: &[String]) -> i32 {
    let path = arg_value(args, "--path")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(default_lock_path);
    match try_single_flight(&path) {
        Ok(Some(_guard)) => {
            println!("free: {}", path.display());
            exit::OK // released as the guard drops here
        }
        Ok(None) => {
            eprintln!("held: {} (another run holds the lock)", path.display());
            exit::REFUSED
        }
        Err(e) => {
            eprintln!("omf-core guard lock: {e}");
            exit::ERR
        }
    }
}

/// Run the `guard` subcommand. `args` are the tokens after `guard`.
pub fn run(args: Vec<String>) -> i32 {
    match args.first().map(String::as_str) {
        Some("caps") => cmd_caps(),
        Some("admit") => cmd_admit(&args[1..]),
        Some("lock") => cmd_lock(&args[1..]),
        Some(other) => {
            eprintln!("omf-core guard: unknown subcommand: {other}");
            eprintln!("usage: omf-core guard <caps|admit|lock> [args]");
            exit::USAGE
        }
        None => {
            eprintln!("usage: omf-core guard <caps|admit|lock> [args]");
            exit::USAGE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn within_budget_admits() {
        assert_eq!(admit(10, 18, false), Admission::Admit);
        assert_eq!(admit(18, 18, true), Admission::Admit);
    }

    #[test]
    fn over_budget_non_mlx_refuses() {
        match admit(20, 18, false) {
            Admission::Refuse(_) => {}
            other => panic!("expected Refuse, got {other:?}"),
        }
    }

    #[test]
    fn over_budget_mlx_warns_never_refuses() {
        // RULE 0: MLX must never refuse -- it stays pageable.
        match admit(99, 18, true) {
            Admission::Warn(_) => {}
            other => panic!("expected Warn, got {other:?}"),
        }
    }

    #[test]
    fn single_flight_is_exclusive() {
        let dir = std::env::var_os("HOME")
            .map(std::path::PathBuf::from)
            .unwrap_or_else(|| std::path::PathBuf::from("."))
            .join("tmp");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!("omf-guard-test-{}.lock", std::process::id()));
        let _ = std::fs::remove_file(&path);

        let first = try_single_flight(&path).unwrap();
        assert!(first.is_some(), "first acquire should succeed");

        // A second non-blocking acquire from a separate fd must be refused
        // while the first guard is still held.
        let second = try_single_flight(&path).unwrap();
        assert!(second.is_none(), "second acquire should be contended");

        drop(first);
        // Once released, it can be acquired again.
        let third = try_single_flight(&path).unwrap();
        assert!(third.is_some(), "acquire after release should succeed");
        drop(third);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn caps_match_clamp_floor() {
        // The doctor-facing constants must equal the manifest clamp floor.
        assert_eq!(MLX_WIRED_LIMIT_GIB, 14);
        assert_eq!(MLX_MEMORY_LIMIT_GIB, 18);
        assert_eq!(MLX_CACHE_LIMIT_GIB, 2);
    }
}
