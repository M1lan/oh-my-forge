//! Integration test: two AF_UNIX clients register + JOIN, then a channel
//! PRIVMSG from one must reach the other, and the joiner's JOIN must be seen.
//!
//! This is the drop-in proof in miniature: raw socket clients speaking the
//! exact wire protocol the partyline Bash client speaks.

use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use erc_llmd::server::Config;
use erc_llmd::{bind_listener, new_state, run_accept_loop};

/// A connected test client with a line-buffered reader.
struct TestClient {
    write: UnixStream,
    reader: BufReader<UnixStream>,
}

impl TestClient {
    fn connect(path: &std::path::Path) -> Self {
        let write = UnixStream::connect(path).expect("connect");
        let read = write.try_clone().expect("clone");
        TestClient {
            write,
            reader: BufReader::new(read),
        }
    }

    fn send(&mut self, line: &str) {
        self.write.write_all(line.as_bytes()).expect("write");
        self.write.write_all(b"\r\n").expect("write crlf");
        self.write.flush().expect("flush");
    }

    fn register_and_join(&mut self, nick: &str, chan: &str) {
        self.send(&format!("NICK {nick}"));
        self.send(&format!("USER {nick} 0 * :{nick} erc-llm agent"));
        self.send(&format!("JOIN {chan}"));
    }

    /// Read lines until `pred` matches one, or the timeout elapses.
    /// Returns all lines read (including the matching one) on success.
    fn wait_for<F: Fn(&str) -> bool>(&mut self, pred: F, timeout: Duration) -> Vec<String> {
        let deadline = Instant::now() + timeout;
        let mut lines = Vec::new();
        self.reader
            .get_ref()
            .set_read_timeout(Some(Duration::from_millis(200)))
            .expect("set timeout");
        loop {
            if Instant::now() >= deadline {
                panic!(
                    "timeout waiting for predicate; saw lines:\n{}",
                    lines.join("\n")
                );
            }
            let mut line = String::new();
            match self.reader.read_line(&mut line) {
                Ok(0) => panic!("EOF; saw lines:\n{}", lines.join("\n")),
                Ok(_) => {
                    let trimmed = line.trim_end_matches(['\r', '\n']).to_string();
                    let matched = pred(&trimmed);
                    lines.push(trimmed);
                    if matched {
                        return lines;
                    }
                }
                Err(ref e)
                    if e.kind() == std::io::ErrorKind::WouldBlock
                        || e.kind() == std::io::ErrorKind::TimedOut =>
                {
                    continue;
                }
                Err(e) => panic!("read error: {e}; saw:\n{}", lines.join("\n")),
            }
        }
    }
}

fn temp_socket_path() -> std::path::PathBuf {
    let pid = std::process::id();
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("erc-llmd-it-{pid}-{nanos}.sock"))
}

#[test]
fn two_clients_see_join_and_privmsg() {
    let sock = temp_socket_path();
    let listener = bind_listener(&sock).expect("bind");
    let state = new_state(Config::default());

    // Run the accept loop on a background thread.
    let st = Arc::clone(&state);
    let server_thread = thread::spawn(move || run_accept_loop(listener, st));

    let chan = "#partyline";
    let timeout = Duration::from_secs(5);

    // alpha joins first.
    let mut alpha = TestClient::connect(&sock);
    alpha.register_and_join("alpha", chan);
    // alpha must see its own welcome (001) and its own JOIN echo.
    alpha.wait_for(|l| l.contains(" 001 alpha "), timeout);
    alpha.wait_for(
        |l| l.contains("alpha!alpha@localhost JOIN #partyline"),
        timeout,
    );

    // beta joins second.
    let mut beta = TestClient::connect(&sock);
    beta.register_and_join("beta", chan);
    beta.wait_for(|l| l.contains(" 001 beta "), timeout);
    beta.wait_for(
        |l| l.contains("beta!beta@localhost JOIN #partyline"),
        timeout,
    );

    // alpha must observe beta's JOIN broadcast.
    alpha.wait_for(
        |l| l.contains("beta!beta@localhost JOIN #partyline"),
        timeout,
    );

    // alpha sends a channel PRIVMSG; beta must receive it.
    alpha.send("PRIVMSG #partyline :hello from alpha");
    let beta_lines = beta.wait_for(
        |l| l.contains("PRIVMSG #partyline :hello from alpha"),
        timeout,
    );
    let got = beta_lines.last().unwrap();
    assert!(
        got.contains("alpha!alpha@localhost PRIVMSG #partyline :hello from alpha"),
        "beta received unexpected line: {got}"
    );

    // The sender must NOT receive an echo of its own channel PRIVMSG.
    // (We assert by confirming alpha doesn't see it within a short window:
    // a quick QUIT from beta should arrive instead of the echoed PRIVMSG.)
    beta.send("QUIT :done");
    let quit_seen = alpha.wait_for(|l| l.contains("beta!beta@localhost QUIT"), timeout);
    assert!(
        quit_seen
            .iter()
            .all(|l| !l.contains("PRIVMSG #partyline :hello from alpha")),
        "alpha should not have received an echo of its own PRIVMSG"
    );

    // Cleanup: drop clients and the socket file. The accept-loop thread is a
    // daemon-style background thread; dropping the listener happens at process
    // exit. We detach it explicitly.
    drop(alpha);
    drop(beta);
    let _ = std::fs::remove_file(&sock);
    drop(server_thread); // detach; test process teardown reaps it
}
