//! omf manifest schema + clamp rules -- the shared contract (F4 / omf-327).
//!
//! This is the authoritative shape of `omf.toml`. The OMX Go dispatcher
//! (omf/dispatch) MUST mirror this struct exactly so that what the compiled
//! floor validates is what the dispatcher routes.
//!
//! Two invariants are encoded here, not just documented:
//!   1. Command templates are argv ARRAYS, never shell strings -- so the
//!      dispatcher never has to re-quote (the `ai-dispatch.zsh:296-302`
//!      eval-quoting footgun). `Vec<String>` makes a shell string
//!      unrepresentable.
//!   2. The manifest may only ever request STRICTER limits than the compiled
//!      floor. `Limits::clamp_to_floor` enforces this: any looser value is
//!      pulled back to the floor and the clamp is logged. Config can tighten
//!      the floor, never loosen it.

use serde::{Deserialize, Serialize};

use crate::guard::{MLX_CACHE_LIMIT_GIB, MLX_MEMORY_LIMIT_GIB, MLX_WIRED_LIMIT_GIB};

/// Top-level `omf.toml` document.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Manifest {
    /// Schema version. Bumped on breaking layout changes.
    #[serde(default)]
    pub schema_version: u32,
    /// Declared backends. A backend is the unit of pluggability.
    #[serde(default, rename = "backend")]
    pub backends: Vec<Backend>,
}

/// The kind of upstream a backend fronts. Drives discovery + passthrough.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Kind {
    Forge,
    Claude,
    Codex,
    Omc,
    Omx,
    Gemini,
    Copilot,
    Vendor,
    LocalLlm,
}

/// Routing class -- which HOME/account universe a backend is allowed to enter.
///
/// The compiled work!=private invariant (OMX omf-sq8) keys off this: a `Work`
/// backend can never resolve a private home, and vice versa. `None` is for
/// account-agnostic tools (e.g. a local LLM).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Routing {
    #[default]
    None,
    Work,
    Private,
}

/// A single backend row.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Backend {
    /// Unique backend name (also the `omf <name>` profile selector).
    pub name: String,
    /// What this backend fronts.
    pub kind: Kind,
    /// Routing class. Defaults to `none` (account-agnostic).
    #[serde(default)]
    pub routing: Routing,
    /// One-shot (`-p`) invocation as an argv array. Empty = not supported.
    #[serde(default)]
    pub oneshot: Vec<String>,
    /// Interactive invocation as an argv array. Empty = not supported.
    #[serde(default)]
    pub interactive: Vec<String>,
    /// Per-child env allowlist: only these names are passed through.
    #[serde(default)]
    pub env_allowlist: Vec<String>,
    /// Whether this backend may run in a danger/yolo mode.
    #[serde(default)]
    pub danger_allowed: bool,
    /// Optional memory limits (local-llm backends). Clamped to the floor.
    #[serde(default)]
    pub limits: Option<Limits>,
}

/// MLX / local-LLM memory limits, in GiB. The manifest may only request
/// values <= the compiled floor; looser requests are clamped.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Limits {
    /// Wired (pinned) memory cap.
    pub wired_gib: u64,
    /// Allocator ceiling.
    pub memory_gib: u64,
    /// Cache (returnable-to-OS) ceiling.
    pub cache_gib: u64,
}

impl Default for Limits {
    fn default() -> Self {
        Limits {
            wired_gib: MLX_WIRED_LIMIT_GIB,
            memory_gib: MLX_MEMORY_LIMIT_GIB,
            cache_gib: MLX_CACHE_LIMIT_GIB,
        }
    }
}

/// Record of a single clamp event, for `omf doctor` to surface.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClampLog {
    pub field: &'static str,
    pub requested: u64,
    pub clamped_to: u64,
}

impl Limits {
    /// Clamp each field to the compiled floor. A manifest may tighten (request
    /// a smaller value) but never loosen. Returns the list of clamps applied
    /// (empty when the manifest was already within the floor).
    #[must_use]
    pub fn clamp_to_floor(&mut self) -> Vec<ClampLog> {
        let mut logs = Vec::new();
        let mut clamp = |field: &'static str, val: &mut u64, floor: u64| {
            if *val > floor {
                logs.push(ClampLog {
                    field,
                    requested: *val,
                    clamped_to: floor,
                });
                *val = floor;
            }
        };
        clamp("wired_gib", &mut self.wired_gib, MLX_WIRED_LIMIT_GIB);
        clamp("memory_gib", &mut self.memory_gib, MLX_MEMORY_LIMIT_GIB);
        clamp("cache_gib", &mut self.cache_gib, MLX_CACHE_LIMIT_GIB);
        logs
    }
}

/// Parse a manifest from TOML text. Clamping is the caller's responsibility
/// (via [`Manifest::clamp_all`]) so the raw parse stays side-effect free.
pub fn parse(toml_text: &str) -> Result<Manifest, toml::de::Error> {
    toml::from_str(toml_text)
}

impl Manifest {
    /// Clamp every backend's limits to the floor, returning all clamp events
    /// tagged with the owning backend name.
    #[must_use]
    pub fn clamp_all(&mut self) -> Vec<(String, ClampLog)> {
        let mut all = Vec::new();
        for b in &mut self.backends {
            if let Some(limits) = b.limits.as_mut() {
                for log in limits.clamp_to_floor() {
                    all.push((b.name.clone(), log));
                }
            }
        }
        all
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_stub_parses() {
        let m = parse("schema_version = 0\n").expect("stub parses");
        assert_eq!(m.schema_version, 0);
        assert!(m.backends.is_empty());
    }

    #[test]
    fn backend_row_with_argv_arrays_parses() {
        let txt = r#"
schema_version = 0

[[backend]]
name = "forge-private"
kind = "forge"
routing = "private"
interactive = ["forge"]
oneshot = ["forge", "-p"]
env_allowlist = ["HOME", "PATH", "TERM"]
"#;
        let m = parse(txt).expect("parses");
        assert_eq!(m.backends.len(), 1);
        let b = &m.backends[0];
        assert_eq!(b.kind, Kind::Forge);
        assert_eq!(b.routing, Routing::Private);
        assert_eq!(b.interactive, vec!["forge"]);
        assert_eq!(b.oneshot, vec!["forge", "-p"]);
        assert!(!b.danger_allowed);
    }

    #[test]
    fn looser_limits_are_clamped_to_floor() {
        // Manifest asks for MORE than the floor allows -> must be clamped down.
        let mut l = Limits {
            wired_gib: 99,
            memory_gib: 99,
            cache_gib: 99,
        };
        let logs = l.clamp_to_floor();
        assert_eq!(l.wired_gib, MLX_WIRED_LIMIT_GIB);
        assert_eq!(l.memory_gib, MLX_MEMORY_LIMIT_GIB);
        assert_eq!(l.cache_gib, MLX_CACHE_LIMIT_GIB);
        assert_eq!(logs.len(), 3);
    }

    #[test]
    fn stricter_limits_are_preserved() {
        // Manifest asks for LESS than the floor -> kept as-is, no clamp.
        let mut l = Limits {
            wired_gib: 8,
            memory_gib: 10,
            cache_gib: 1,
        };
        let logs = l.clamp_to_floor();
        assert_eq!(l.wired_gib, 8);
        assert_eq!(l.memory_gib, 10);
        assert_eq!(l.cache_gib, 1);
        assert!(logs.is_empty());
    }
}
