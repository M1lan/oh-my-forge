//! omf-core -- the compiled security floor for omf.
//!
//! One small, audited binary. Two responsibilities, both safety-critical:
//!   * `secrets` -- keychain read (hands-off) + private 1Password vault r/w
//!     + per-child env allowlist. (filled in by F2 / omf-mqu)
//!   * `guard`   -- memory-guard admission preflight + single-flight flock
//!     + MLX cap constants. (filled in by F3 / omf-bfl)
//!
//! The Go dispatcher (omf/dispatch, OMX lane) shells out to this binary;
//! it never links it. Keep the surface a stable argv/exit-code contract.

pub mod guard;
pub mod manifest;
pub mod secrets;

/// Process-wide exit codes. Stable contract for the Go dispatcher.
pub mod exit {
    /// Success.
    pub const OK: i32 = 0;
    /// Generic failure.
    pub const ERR: i32 = 1;
    /// Usage error (bad/missing subcommand or args).
    pub const USAGE: i32 = 2;
    /// Admission refused: requested allocation would exceed the safety floor.
    pub const REFUSED: i32 = 3;
}
