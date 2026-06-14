//! Library surface for erc-llmd, exposing the protocol engine for integration
//! tests and embedding. The `erc-llmd` binary (`main.rs`) is the primary
//! entry point; this lib re-exports the same modules it uses.

pub mod client;
pub mod parser;
pub mod server;
pub mod toon;

use std::os::unix::net::UnixListener;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use server::{Config, ServerState};

/// Run the accept loop on an already-bound listener until it is closed.
///
/// Shared by the binary and integration tests so both exercise identical
/// connection-handling code (thread-per-connection + `Arc<Mutex<_>>`).
pub fn run_accept_loop(listener: UnixListener, state: Arc<Mutex<ServerState>>) {
    let next_id = AtomicU64::new(1);
    for incoming in listener.incoming() {
        let stream = match incoming {
            Ok(s) => s,
            Err(_) => continue,
        };
        let write_half = match stream.try_clone() {
            Ok(s) => s,
            Err(_) => continue,
        };
        let id = next_id.fetch_add(1, Ordering::Relaxed);
        {
            let mut guard = state.lock().unwrap_or_else(|p| p.into_inner());
            guard.add_client(id, write_half);
        }
        let st = Arc::clone(&state);
        thread::spawn(move || client::serve(id, stream, st));
    }
}

/// Bind a listener at `path` with the same security posture as the daemon:
/// 0700 parent dir, stale socket removed, socket chmod 0600.
pub fn bind_listener(path: &Path) -> std::io::Result<UnixListener> {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)?;
        let _ = fs::set_permissions(dir, fs::Permissions::from_mode(0o700));
    }
    if path.exists() {
        fs::remove_file(path)?;
    }
    let listener = UnixListener::bind(path)?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    Ok(listener)
}

/// Convenience: build a default `ServerState` behind a shared mutex.
pub fn new_state(cfg: Config) -> Arc<Mutex<ServerState>> {
    Arc::new(Mutex::new(ServerState::new(cfg)))
}
