//! Secrets subsystem (F2 / omf-mqu).
//!
//! Responsibilities, all safety-critical:
//!   * read the `mein-zsh-op-cache` login-Keychain item HANDS-OFF via
//!     `/usr/bin/security` -- NEVER write it (zsh owns writes there);
//!   * parse its base64/TSV payload (header `ts<TAB><epoch>`, then
//!     `NAME<TAB>value` lines) and classify freshness against a TTL;
//!   * build a per-child env from an ALLOWLIST of names keyed by account +
//!     op-account; values are zeroized after use;
//!   * read the user's PRIVATE 1Password vault (`my.1password.eu`) via `op`;
//!     REFUSE the work account (`istase.1password.eu`) for private routes;
//!   * no-op fallback is cache-only then refuse -- never a plaintext path.
//!
//! Payload semantics mirror `op-secrets.zsh:86-112` exactly so the two
//! readers agree byte-for-byte on what the cache means.

use std::collections::BTreeMap;
use std::process::Command;

use base64::Engine as _;
use zeroize::Zeroize;

use crate::exit;

/// Login-Keychain service name holding the resolved-secrets cache.
pub const KEYCHAIN_SERVICE: &str = "mein-zsh-op-cache";
/// The user's PRIVATE 1Password account. The only account omf may read/write.
pub const PRIVATE_OP_ACCOUNT: &str = "my.1password.eu";
/// The WORK 1Password account. omf must NEVER touch this for private routes.
pub const WORK_OP_ACCOUNT: &str = "istase.1password.eu";

/// The 1Password CLI, pinned to its Homebrew path. Resolving `op` off $PATH
/// would let a planted binary intercept private-vault reads.
pub const OP_BIN: &str = "/opt/homebrew/bin/op";
/// Default cache TTL: bounds the keychain exposure window, not token validity.
pub const DEFAULT_TTL_SECS: u64 = 86_400;

/// A secret value that scrubs its bytes on drop.
#[derive(Clone, Default)]
pub struct Secret(String);

impl Secret {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Drop for Secret {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

/// Cache freshness relative to the TTL. A stale cache is still usable -- the
/// TTL only bounds the keychain exposure window, not token validity.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Freshness {
    Fresh,
    Stale,
}

/// Parsed secrets cache. Names are not secret; values are [`Secret`].
pub struct Cache {
    pub ts: u64,
    pub freshness: Freshness,
    pub vars: BTreeMap<String, Secret>,
}

/// Returns true iff `name` is a valid env identifier: `[A-Za-z_][A-Za-z0-9_]*`.
/// Mirrors the `[A-Za-z_]([A-Za-z0-9_])#` guard in `op-secrets.zsh:76` so the
/// two readers skip the same comment/junk lines.
fn is_env_name(name: &str) -> bool {
    let mut chars = name.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

/// Parse the decoded cache payload. `now`/`ttl` classify freshness.
///
/// Layout (faithful to the zsh writer):
///   line 0:   `ts<TAB><epoch>`
///   line 1..: `NAME<TAB>value` (lines failing [`is_env_name`] are skipped)
///
/// Returns `None` when there is no header, the epoch is unparseable, or the
/// payload is header-only (treated as a miss, matching `op-secrets.zsh:97`).
pub fn parse_payload(payload: &str, now: u64, ttl: u64) -> Option<Cache> {
    let (header, body) = payload.split_once('\n')?;
    let ts_str = header.strip_prefix("ts\t")?;
    let ts: u64 = ts_str.trim().parse().ok()?;
    if body.is_empty() {
        return None; // header-only -> miss
    }
    let freshness = if now.saturating_sub(ts) < ttl {
        Freshness::Fresh
    } else {
        Freshness::Stale
    };
    let mut vars = BTreeMap::new();
    for line in body.lines() {
        let Some((k, v)) = line.split_once('\t') else {
            continue;
        };
        if !is_env_name(k) {
            continue;
        }
        vars.insert(k.to_string(), Secret(v.to_string()));
    }
    Some(Cache {
        ts,
        freshness,
        vars,
    })
}

/// Read the cache base64 blob from the login Keychain, hands-off. Returns
/// `None` on any failure (no keychain, no entry, non-UTF8). NEVER writes.
fn read_keychain_b64(user: &str) -> Option<String> {
    let out = Command::new("/usr/bin/security")
        .args(["find-generic-password", "-a", user, "-s", KEYCHAIN_SERVICE, "-w"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let s = String::from_utf8(out.stdout).ok()?;
    let trimmed = s.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

/// Read + decode + parse the cache from the Keychain for `user`.
pub fn read_cache(user: &str, now: u64, ttl: u64) -> Option<Cache> {
    let b64 = read_keychain_b64(user)?;
    let mut bytes = base64::engine::general_purpose::STANDARD
        .decode(b64.as_bytes())
        .ok()?;
    let mut payload = String::from_utf8(bytes.clone()).ok()?;
    bytes.zeroize();
    let cache = parse_payload(&payload, now, ttl);
    payload.zeroize(); // scrub the secret-bearing payload string
    cache
}

/// Filter a cache to the allowlisted names that are present, in allowlist
/// order. The result borrows the cache; nothing is copied until emitted.
pub fn filter_allowlist<'a>(cache: &'a Cache, allow: &[String]) -> Vec<(&'a str, &'a str)> {
    allow
        .iter()
        .filter_map(|name| {
            cache
                .vars
                .get_key_value(name)
                .map(|(k, v)| (k.as_str(), v.as_str()))
        })
        .collect()
}

/// Refuse any op-account that is the work account. Returns `Err` with a
/// stable message when the work account is requested for a private route.
pub fn assert_private_account(op_account: &str) -> Result<(), String> {
    if op_account == WORK_OP_ACCOUNT {
        return Err(format!(
            "refusing work vault ({WORK_OP_ACCOUNT}) for a private route"
        ));
    }
    Ok(())
}

/// Read a single reference from the private vault via `op`. Refuses the work
/// account. Returns the secret value on success.
pub fn op_read(reference: &str, op_account: &str) -> Result<Secret, String> {
    assert_private_account(op_account)?;
    // Reject anything that is not an op:// reference. This both catches typos
    // and prevents a leading-dash argument from being parsed as an op flag
    // (belt-and-braces with the `--` separator below).
    if !reference.starts_with("op://") {
        return Err("op read: reference must be an op:// URI".to_string());
    }
    // Pin the Homebrew op binary rather than resolving `op` off $PATH: the
    // keychain reader already pins /usr/bin/security, and a planted `op` on
    // PATH would otherwise intercept every private-vault read.
    let out = Command::new(OP_BIN)
        .args(["read", "--account", op_account, "--", reference])
        .output()
        .map_err(|e| format!("op read failed to spawn: {e}"))?;
    if !out.status.success() {
        return Err("op read failed".to_string());
    }
    let mut s = match String::from_utf8(out.stdout) {
        Ok(s) => s,
        Err(e) => {
            // Wipe the raw bytes before dropping them on the error path too.
            let mut bytes = e.into_bytes();
            for b in bytes.iter_mut() {
                *b = 0;
            }
            return Err("op read: non-UTF8".to_string());
        }
    };
    let value = Secret(s.trim_end_matches('\n').to_string());
    s.zeroize();
    Ok(value)
}

// --- CLI -------------------------------------------------------------------

fn arg_value<'a>(args: &'a [String], flag: &str) -> Option<&'a str> {
    args.iter()
        .position(|a| a == flag)
        .and_then(|i| args.get(i + 1))
        .map(String::as_str)
}

fn now_epoch() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// `secrets status [--ttl N] [--allow A,B]` -- print cache age + count of
/// present names. Names only when `--allow` given; NEVER values.
fn cmd_status(args: &[String]) -> i32 {
    let user = std::env::var("USER").unwrap_or_default();
    let ttl = arg_value(args, "--ttl")
        .and_then(|s| s.parse().ok())
        .unwrap_or(DEFAULT_TTL_SECS);
    let now = now_epoch();
    match read_cache(&user, now, ttl) {
        None => {
            println!("cache: none");
            exit::OK
        }
        Some(cache) => {
            let age = now.saturating_sub(cache.ts);
            let state = match cache.freshness {
                Freshness::Fresh => "fresh",
                Freshness::Stale => "stale",
            };
            println!("cache: age {}h{:02}m ({state})", age / 3600, (age % 3600) / 60);
            if let Some(allow) = arg_value(args, "--allow") {
                let allow: Vec<String> = allow.split(',').map(String::from).collect();
                let present: Vec<&str> = filter_allowlist(&cache, &allow)
                    .into_iter()
                    .map(|(k, _)| k)
                    .collect();
                println!("present: {} of {} allowlisted", present.len(), allow.len());
                if !present.is_empty() {
                    println!("names: {}", present.join(" "));
                }
            } else {
                println!("vars: {} cached", cache.vars.len());
            }
            exit::OK
        }
    }
}

/// `secrets env --allow A,B --op-account <acct>` -- emit NUL-delimited
/// `NAME=value` for allowlisted present names, for the dispatcher to assemble
/// a scrubbed child env. Refuses the work account; refuses with no cache.
fn cmd_env(args: &[String]) -> i32 {
    let op_account = arg_value(args, "--op-account").unwrap_or(PRIVATE_OP_ACCOUNT);
    if let Err(msg) = assert_private_account(op_account) {
        eprintln!("omf-core secrets env: {msg}");
        return exit::REFUSED;
    }
    let Some(allow) = arg_value(args, "--allow") else {
        eprintln!("omf-core secrets env: --allow <NAME,NAME,...> is required");
        return exit::USAGE;
    };
    let allow: Vec<String> = allow.split(',').map(String::from).collect();
    let user = std::env::var("USER").unwrap_or_default();
    let ttl = arg_value(args, "--ttl")
        .and_then(|s| s.parse().ok())
        .unwrap_or(DEFAULT_TTL_SECS);
    let now = now_epoch();
    let Some(cache) = read_cache(&user, now, ttl) else {
        // no-op fallback = cache-only then refuse. No plaintext path.
        eprintln!("omf-core secrets env: no keychain cache -- refusing (no plaintext fallback)");
        return exit::REFUSED;
    };
    use std::io::Write as _;
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    for (k, v) in filter_allowlist(&cache, &allow) {
        // NUL-delimited so values may contain any byte except NUL. A failed
        // write must NOT be reported as success -- a partial secret stream is
        // a hard error (RULE 0: no false "done").
        if write!(out, "{k}={v}\0").is_err() {
            eprintln!("omf-core secrets env: write failed mid-stream -- aborting (partial output)");
            return exit::ERR;
        }
    }
    if out.flush().is_err() {
        eprintln!("omf-core secrets env: flush failed -- output may be incomplete");
        return exit::ERR;
    }
    exit::OK
}

/// `secrets read <op://reference> [--op-account <acct>]` -- print a private
/// vault value. Refuses the work account.
fn cmd_read(args: &[String]) -> i32 {
    let Some(reference) = args.first() else {
        eprintln!("omf-core secrets read: <op://reference> is required");
        return exit::USAGE;
    };
    let op_account = arg_value(args, "--op-account").unwrap_or(PRIVATE_OP_ACCOUNT);
    match op_read(reference, op_account) {
        Ok(value) => {
            println!("{}", value.as_str());
            exit::OK
        }
        Err(msg) => {
            eprintln!("omf-core secrets read: {msg}");
            // work-account refusal is REFUSED; other op failures are ERR.
            if msg.contains("work vault") {
                exit::REFUSED
            } else {
                exit::ERR
            }
        }
    }
}

/// Run the `secrets` subcommand. `args` are the tokens after `secrets`.
pub fn run(args: Vec<String>) -> i32 {
    match args.first().map(String::as_str) {
        Some("status") => cmd_status(&args[1..]),
        Some("env") => cmd_env(&args[1..]),
        Some("read") => cmd_read(&args[1..]),
        Some(other) => {
            eprintln!("omf-core secrets: unknown subcommand: {other}");
            eprintln!("usage: omf-core secrets <status|env|read> [args]");
            exit::USAGE
        }
        None => {
            eprintln!("usage: omf-core secrets <status|env|read> [args]");
            exit::USAGE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn payload(ts: u64, body: &str) -> String {
        format!("ts\t{ts}\n{body}")
    }

    #[test]
    fn fresh_cache_parses_tsv() {
        let p = payload(1000, "FOO\tbar\nBAZ\tqux\n");
        let c = parse_payload(&p, 1010, 86_400).expect("parses");
        assert_eq!(c.ts, 1000);
        assert_eq!(c.freshness, Freshness::Fresh);
        assert_eq!(c.vars.get("FOO").unwrap().as_str(), "bar");
        assert_eq!(c.vars.get("BAZ").unwrap().as_str(), "qux");
    }

    #[test]
    fn stale_cache_still_usable() {
        let p = payload(0, "FOO\tbar\n");
        let c = parse_payload(&p, 1_000_000, 86_400).expect("parses");
        assert_eq!(c.freshness, Freshness::Stale);
        assert_eq!(c.vars.get("FOO").unwrap().as_str(), "bar");
    }

    #[test]
    fn header_only_is_a_miss() {
        // Matches op-secrets.zsh:97 -- ts line only is treated as no cache.
        assert!(parse_payload("ts\t1000\n", 1010, 86_400).is_none());
        assert!(parse_payload("ts\t1000", 1010, 86_400).is_none());
    }

    #[test]
    fn junk_and_comment_lines_skipped() {
        let p = payload(1000, "# a comment\nGOOD\tval\n1BAD\tx\nALSO_GOOD\ty\n");
        let c = parse_payload(&p, 1010, 86_400).unwrap();
        assert_eq!(c.vars.len(), 2);
        assert!(c.vars.contains_key("GOOD"));
        assert!(c.vars.contains_key("ALSO_GOOD"));
        assert!(!c.vars.contains_key("1BAD"));
    }

    #[test]
    fn value_may_contain_shell_metachars() {
        // TSV-not-source: a value with $/`/quotes is data, never code.
        let p = payload(1000, "TOK\t$(rm -rf /)`x`\"q\"\n");
        let c = parse_payload(&p, 1010, 86_400).unwrap();
        assert_eq!(c.vars.get("TOK").unwrap().as_str(), "$(rm -rf /)`x`\"q\"");
    }

    #[test]
    fn allowlist_filters_to_present_names_only() {
        let p = payload(1000, "A\t1\nB\t2\nC\t3\n");
        let c = parse_payload(&p, 1010, 86_400).unwrap();
        let allow = vec!["A".to_string(), "C".to_string(), "MISSING".to_string()];
        let got = filter_allowlist(&c, &allow);
        assert_eq!(got, vec![("A", "1"), ("C", "3")]);
    }

    #[test]
    fn work_account_is_refused() {
        assert!(assert_private_account(WORK_OP_ACCOUNT).is_err());
        assert!(assert_private_account(PRIVATE_OP_ACCOUNT).is_ok());
    }

    #[test]
    fn op_read_rejects_non_op_reference() {
        // Refused before any spawn: a non-op:// reference (incl. a leading-dash
        // flag-injection attempt) never reaches the op binary.
        assert!(op_read("--version", PRIVATE_OP_ACCOUNT).is_err());
        assert!(op_read("/etc/passwd", PRIVATE_OP_ACCOUNT).is_err());
    }

    #[test]
    fn op_read_refuses_work_account_before_anything_else() {
        // Work account is refused even for a well-formed op:// reference.
        assert!(op_read("op://Private/item/field", WORK_OP_ACCOUNT).is_err());
    }

    #[test]
    fn is_env_name_matches_zsh_guard() {
        assert!(is_env_name("FOO"));
        assert!(is_env_name("_x9"));
        assert!(!is_env_name("9x"));
        assert!(!is_env_name("a-b"));
        assert!(!is_env_name(""));
        assert!(!is_env_name("# comment"));
    }
}
