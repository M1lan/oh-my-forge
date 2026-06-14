//! Per-connection read loop: line framing + handoff to shared server state.
//!
//! Mirrors `erc-llm-ircd--filter`: accumulate bytes, split on `\n`, strip a
//! trailing `\r`, drop over-long lines (keep the connection), dispatch each
//! complete line under the shared lock. On EOF/read error the client is
//! dropped (QUIT broadcast to shared channels).

use std::io::Read;
use std::os::unix::net::UnixStream;
use std::sync::{Arc, Mutex};

use crate::server::ServerState;

/// Serve a single accepted connection until EOF or error.
///
/// `id` is the unique client id already registered in `state` by the caller.
pub fn serve(id: u64, mut stream: UnixStream, state: Arc<Mutex<ServerState>>) {
    let max_line = {
        // Read the cap once; avoids holding the lock during IO.
        let mut buf: Vec<u8> = Vec::with_capacity(8192);
        let mut chunk = [0u8; 4096];
        let max_line = MAX_BUFFER;

        loop {
            let n = match stream.read(&mut chunk) {
                Ok(0) => break, // EOF
                Ok(n) => n,
                Err(_) => break, // read error -> treat as disconnect
            };
            buf.extend_from_slice(&chunk[..n]);

            // Process every complete line currently in the buffer.
            while let Some(pos) = buf.iter().position(|&b| b == b'\n') {
                let mut line: Vec<u8> = buf.drain(..=pos).collect();
                line.pop(); // remove '\n'
                if line.last() == Some(&b'\r') {
                    line.pop(); // remove trailing '\r'
                }
                // Decode lossily so a stray non-UTF8 byte cannot kill the loop.
                let text = String::from_utf8_lossy(&line);
                if text.is_empty() {
                    continue;
                }
                let mut guard = state.lock().unwrap_or_else(|p| p.into_inner());
                guard.handle_line(id, &text);
            }

            // Guard against unbounded growth from a peer that never sends '\n'.
            if buf.len() > max_line {
                buf.clear();
            }
        }
        max_line
    };
    let _ = max_line;

    // Connection closed: drop the client (broadcasts QUIT to shared channels).
    let mut guard = state.lock().unwrap_or_else(|p| p.into_inner());
    guard.drop_client(id, "Connection closed");
}

/// Hard cap on the partial-line accumulation buffer (bytes). A single line is
/// independently capped in `ServerState::handle_line`; this bounds the case of
/// a peer that streams without ever sending a newline.
const MAX_BUFFER: usize = 1 << 20; // 1 MiB
