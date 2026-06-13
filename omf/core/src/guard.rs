//! Memory-guard subsystem -- scaffold.
//!
//! Implemented by F3 (omf-bfl). Contract, in brief:
//!   * admission preflight as a LIGHT backstop -- warn if peak_RSS would
//!     exceed claimable; never refuse-by-default for MLX;
//!   * single-flight `flock` on `~/.cache/omf/runtime.lock`;
//!   * surface the proven MLX cap constants for `omf doctor` to verify.
//!
//! The MLX caps below are the proven `mlx_lm_server_safe` split. They are
//! the floor's source of truth; the manifest (omf.toml) may only request
//! STRICTER values -- the compiled core clamps anything looser and logs it.

use crate::exit;

/// MLX wired-memory pin, in GiB. At most this is pinned; the remainder of
/// the model stays pageable so the OS can always reclaim pages.
pub const MLX_WIRED_LIMIT_GIB: u64 = 14;
/// MLX allocator ceiling, in GiB. The allocator errors near this cap rather
/// than at MLX's ~27 GiB default.
pub const MLX_MEMORY_LIMIT_GIB: u64 = 18;
/// MLX cache ceiling, in GiB. Freed buffers above this return to the OS.
pub const MLX_CACHE_LIMIT_GIB: u64 = 2;

/// Run the `guard` subcommand. `_args` are the tokens after `guard`.
pub fn run(_args: Vec<String>) -> i32 {
    eprintln!("omf-core guard: not yet implemented (F3 / omf-bfl)");
    exit::ERR
}
