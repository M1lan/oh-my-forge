//! Server state + command dispatch, replicating erc-llm-ircd.el behaviour.
//!
//! Concurrency model: one OS thread per connection. All shared mutable state
//! (clients, channels) lives behind a single `Arc<Mutex<ServerState>>`. Each
//! client owns a cloned `UnixStream` write half stored in the shared map so
//! any thread can deliver a line to any client (channel broadcast, DM).
//!
//! This slice is REAL CLIENTS ONLY: no virtual participants, no inject hook,
//! no control plane. Every member of a channel is a live socket client.

use std::collections::HashMap;
use std::io::Write;
use std::os::unix::net::UnixStream;

use crate::parser::{self, Message};

/// Configuration shared across all connections.
#[derive(Clone)]
pub struct Config {
    pub server_name: String,
    pub default_channel: String,
    pub max_line_bytes: usize,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            server_name: "erc-llm.local".to_string(),
            default_channel: "#partyline".to_string(),
            max_line_bytes: 8192,
        }
    }
}

/// Per-client registration + identity state.
struct Client {
    /// Cloned write half of the client's socket (for delivery from any thread).
    stream: UnixStream,
    nick: Option<String>,
    user: Option<String>,
    registered: bool,
    /// True while mid CAP negotiation (between CAP LS and CAP END).
    capneg: bool,
}

/// A channel and its current membership.
///
/// Note: the channel display name is not stored. Both the .el and the wire
/// protocol echo back the exact channel token the client supplied (JOIN/PART/
/// PRIVMSG carry the client's spelling), and membership/topic are keyed by the
/// downcased name, so a separate canonical display name is never needed.
struct Channel {
    topic: String,
    /// Set of client ids currently in the channel.
    members: Vec<u64>,
}

/// All shared server state.
pub struct ServerState {
    cfg: Config,
    clients: HashMap<u64, Client>,
    /// Map downcased channel name -> channel.
    channels: HashMap<String, Channel>,
}

const DEFAULT_TOPIC: &str = "erc-llm partyline — @-mention a harness or capability";

impl ServerState {
    pub fn new(cfg: Config) -> Self {
        let mut channels = HashMap::new();
        channels.insert(
            cfg.default_channel.to_ascii_lowercase(),
            Channel {
                topic: DEFAULT_TOPIC.to_string(),
                members: Vec::new(),
            },
        );
        ServerState {
            cfg,
            clients: HashMap::new(),
            channels,
        }
    }

    /// Register a freshly-accepted connection, returning its client id.
    pub fn add_client(&mut self, id: u64, stream: UnixStream) {
        self.clients.insert(
            id,
            Client {
                stream,
                nick: None,
                user: None,
                registered: false,
                capneg: false,
            },
        );
    }

    // ---- low-level send helpers -------------------------------------------

    /// Send a raw protocol line (CRLF appended) to a single client by id.
    /// Send failures are swallowed (a dying peer is dropped elsewhere).
    fn send(&mut self, id: u64, line: &str) {
        if let Some(c) = self.clients.get_mut(&id) {
            let _ = c.stream.write_all(line.as_bytes());
            let _ = c.stream.write_all(b"\r\n");
            let _ = c.stream.flush();
        }
    }

    /// Send a numeric reply: `:server NNN <target> <text>`.
    fn snum(&mut self, id: u64, num: u16, target: &str, text: &str) {
        let line = format!(":{} {:03} {} {}", self.cfg.server_name, num, target, text);
        self.send(id, &line);
    }

    fn prefix(nick: &str) -> String {
        format!("{nick}!{nick}@localhost")
    }

    /// Broadcast a raw line to every member of a channel, optionally skipping
    /// one client id (the sender). Mirrors `erc-llm-ircd--broadcast`.
    fn broadcast(&mut self, chan_key: &str, line: &str, except: Option<u64>) {
        let ids: Vec<u64> = match self.channels.get(chan_key) {
            Some(ch) => ch
                .members
                .iter()
                .copied()
                .filter(|m| Some(*m) != except)
                .collect(),
            None => return,
        };
        for id in ids {
            self.send(id, line);
        }
    }

    // ---- identity / lookup helpers ----------------------------------------

    fn nick_of(&self, id: u64) -> Option<String> {
        self.clients.get(&id).and_then(|c| c.nick.clone())
    }

    fn is_registered(&self, id: u64) -> bool {
        self.clients.get(&id).map(|c| c.registered).unwrap_or(false)
    }

    /// Find a client id by (case-insensitive) nick.
    fn find_client(&self, nick: &str) -> Option<u64> {
        let want = nick.to_ascii_lowercase();
        self.clients.iter().find_map(|(id, c)| {
            c.nick
                .as_ref()
                .filter(|n| n.to_ascii_lowercase() == want)
                .map(|_| *id)
        })
    }

    /// True if `nick` is already taken by some client.
    fn nick_taken(&self, nick: &str) -> bool {
        self.find_client(nick).is_some()
    }

    /// Member nicks of a channel, in stable membership order.
    fn member_names(&self, chan_key: &str) -> Vec<String> {
        match self.channels.get(chan_key) {
            Some(ch) => ch
                .members
                .iter()
                .filter_map(|id| self.nick_of(*id))
                .collect(),
            None => Vec::new(),
        }
    }

    fn valid_nick(nick: &str) -> bool {
        if nick.is_empty() || nick.len() > 64 {
            return false;
        }
        let mut chars = nick.chars();
        let first = chars.next().unwrap();
        if !first.is_ascii_alphabetic() {
            return false;
        }
        chars.all(|c| {
            c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.' | '|' | '^' | '`' | '{' | '}')
        })
    }

    // ---- registration ------------------------------------------------------

    /// Complete registration once NICK and USER are present and not mid-CAP.
    fn maybe_register(&mut self, id: u64) {
        let ready = match self.clients.get(&id) {
            Some(c) => !c.registered && !c.capneg && c.nick.is_some() && c.user.is_some(),
            None => false,
        };
        if !ready {
            return;
        }
        if let Some(c) = self.clients.get_mut(&id) {
            c.registered = true;
        }
        let nick = self.nick_of(id).unwrap_or_default();
        let srv = self.cfg.server_name.clone();
        self.snum(
            id,
            1,
            &nick,
            &format!(":Welcome to the erc-llm partyline {nick}"),
        );
        self.snum(
            id,
            2,
            &nick,
            &format!(":Your host is {srv}, running erc-llm-ircd/0.1"),
        );
        self.snum(
            id,
            3,
            &nick,
            &format!(
                ":This server is localhost-only (AF_UNIX); created {}",
                now_iso8601()
            ),
        );
        self.snum(id, 4, &nick, &format!("{srv} erc-llm-ircd/0.1 o nt"));
        self.snum(
            id,
            5,
            &nick,
            "CHANTYPES=# NICKLEN=64 NETWORK=erc-llm CASEMAPPING=ascii :are supported",
        );
        self.snum(id, 375, &nick, &format!(":- {srv} message of the day -"));
        self.snum(
            id,
            372,
            &nick,
            ":- You are inside Emacs. Everything else is off-screen.",
        );
        self.snum(id, 376, &nick, ":End of /MOTD command.");
    }

    // ---- public entry points ----------------------------------------------

    /// Handle a complete inbound line from client `id`.
    ///
    /// Over-long lines are dropped (connection kept). Empty lines are ignored.
    pub fn handle_line(&mut self, id: u64, raw: &str) {
        if raw.len() > self.cfg.max_line_bytes {
            return;
        }
        let msg = match parser::parse(raw) {
            Some(m) => m,
            None => return,
        };
        self.dispatch(id, &msg);
    }

    /// Drop a client (EOF / QUIT): broadcast QUIT to shared channels and
    /// remove from all membership. Mirrors `erc-llm-ircd--drop-client`.
    pub fn drop_client(&mut self, id: u64, reason: &str) {
        if let Some(nick) = self.nick_of(id) {
            let line = format!(":{} QUIT :{}", Self::prefix(&nick), reason);
            // Channels this client is a member of.
            let keys: Vec<String> = self
                .channels
                .iter()
                .filter(|(_, ch)| ch.members.contains(&id))
                .map(|(k, _)| k.clone())
                .collect();
            for key in &keys {
                if let Some(ch) = self.channels.get_mut(key) {
                    ch.members.retain(|m| *m != id);
                }
                self.broadcast(key, &line, Some(id));
            }
        }
        self.clients.remove(&id);
    }

    fn dispatch(&mut self, id: u64, msg: &Message) {
        match msg.command.as_str() {
            "CAP" => self.cmd_cap(id, &msg.params),
            "NICK" => self.cmd_nick(id, &msg.params),
            "USER" => self.cmd_user(id, &msg.params),
            "PING" => {
                let srv = self.cfg.server_name.clone();
                let arg = msg.params.first().map(String::as_str).unwrap_or("");
                let line = format!(":{srv} PONG {srv} :{arg}");
                self.send(id, &line);
            }
            "PONG" => {}
            "JOIN" => self.cmd_join(id, &msg.params),
            "PART" => self.cmd_part(id, &msg.params),
            "PRIVMSG" => self.cmd_privmsg(id, &msg.params, false),
            "NOTICE" => self.cmd_privmsg(id, &msg.params, true),
            "MODE" => self.cmd_mode(id, &msg.params),
            "WHO" => self.cmd_who(id, &msg.params),
            "NAMES" => {
                if let Some(chan) = msg.params.first() {
                    self.send_names(id, chan);
                }
            }
            "TOPIC" => self.cmd_topic(id, &msg.params),
            "QUIT" => {
                let reason = msg
                    .params
                    .first()
                    .cloned()
                    .unwrap_or_else(|| "Client quit".to_string());
                self.drop_client(id, &reason);
            }
            // No-ops while registered or not.
            "WHOIS" | "USERHOST" | "ISON" | "LIST" | "LUSERS" | "AWAY" => {}
            other => {
                if self.is_registered(id) {
                    let nick = self.nick_of(id).unwrap_or_else(|| "*".to_string());
                    self.snum(id, 421, &nick, &format!("{other} :Unknown command"));
                }
            }
        }
    }

    fn cmd_cap(&mut self, id: u64, params: &[String]) {
        let sub = params.first().map(|s| s.to_uppercase()).unwrap_or_default();
        let nick = self.nick_of(id).unwrap_or_else(|| "*".to_string());
        let srv = self.cfg.server_name.clone();
        match sub.as_str() {
            "LS" => {
                if let Some(c) = self.clients.get_mut(&id) {
                    c.capneg = true;
                }
                self.send(id, &format!(":{srv} CAP {nick} LS :"));
            }
            "REQ" => {
                let req = params.get(1).map(String::as_str).unwrap_or("");
                self.send(id, &format!(":{srv} CAP {nick} NAK :{req}"));
            }
            "LIST" => {
                self.send(id, &format!(":{srv} CAP {nick} LIST :"));
            }
            "END" => {
                if let Some(c) = self.clients.get_mut(&id) {
                    c.capneg = false;
                }
                self.maybe_register(id);
            }
            _ => {}
        }
    }

    fn cmd_nick(&mut self, id: u64, params: &[String]) {
        let nick = params.first().cloned();
        let cur = self.nick_of(id);
        let cur_target = cur.clone().unwrap_or_else(|| "*".to_string());

        match nick {
            Some(ref n) if Self::valid_nick(n) => {
                // In-use check: only if changing to a different nick.
                let same = cur
                    .as_ref()
                    .map(|c| c.eq_ignore_ascii_case(n))
                    .unwrap_or(false);
                if !same && self.nick_taken(n) {
                    self.snum(
                        id,
                        433,
                        &cur_target,
                        &format!("{n} :Nickname is already in use"),
                    );
                    return;
                }
                let old = cur.clone();
                if let Some(c) = self.clients.get_mut(&id) {
                    c.nick = Some(n.clone());
                }
                if self.is_registered(id) {
                    // Registered nick-change: broadcast to shared channels.
                    if let Some(old) = old {
                        let line = format!(":{} NICK :{}", Self::prefix(&old), n);
                        let keys: Vec<String> = self
                            .channels
                            .iter()
                            .filter(|(_, ch)| ch.members.contains(&id))
                            .map(|(k, _)| k.clone())
                            .collect();
                        for key in &keys {
                            self.broadcast(key, &line, None);
                        }
                    }
                } else {
                    self.maybe_register(id);
                }
            }
            _ => {
                let bad = nick.unwrap_or_default();
                self.snum(id, 432, &cur_target, &format!("{bad} :Erroneous nickname"));
            }
        }
    }

    fn cmd_user(&mut self, id: u64, params: &[String]) {
        if let Some(c) = self.clients.get_mut(&id) {
            c.user = Some(
                params
                    .first()
                    .cloned()
                    .unwrap_or_else(|| "user".to_string()),
            );
        }
        self.maybe_register(id);
    }

    fn send_names(&mut self, id: u64, channel: &str) {
        let nick = self.nick_of(id).unwrap_or_else(|| "*".to_string());
        let key = channel.to_ascii_lowercase();
        let names = self.member_names(&key).join(" ");
        self.snum(id, 353, &nick, &format!("= {channel} :{names}"));
        self.snum(id, 366, &nick, &format!("{channel} :End of /NAMES list."));
    }

    fn cmd_join(&mut self, id: u64, params: &[String]) {
        if !self.is_registered(id) {
            return;
        }
        let nick = match self.nick_of(id) {
            Some(n) => n,
            None => return,
        };
        let arg = params.first().cloned().unwrap_or_default();
        for channel in arg.split(',').filter(|c| !c.is_empty()) {
            if !channel.starts_with('#') {
                continue;
            }
            let key = channel.to_ascii_lowercase();
            let ch = self.channels.entry(key.clone()).or_insert_with(|| Channel {
                topic: DEFAULT_TOPIC.to_string(),
                members: Vec::new(),
            });
            if !ch.members.contains(&id) {
                ch.members.push(id);
            }
            let topic = ch.topic.clone();
            let join = format!(":{} JOIN {}", Self::prefix(&nick), channel);
            // Echo to joiner, then broadcast to the rest.
            self.send(id, &join);
            self.broadcast(&key, &join, Some(id));
            self.snum(id, 332, &nick, &format!("{channel} :{topic}"));
            self.send_names(id, channel);
        }
    }

    fn cmd_part(&mut self, id: u64, params: &[String]) {
        let nick = match self.nick_of(id) {
            Some(n) => n,
            None => return,
        };
        let arg = params.first().cloned().unwrap_or_default();
        for channel in arg.split(',').filter(|c| !c.is_empty()) {
            let key = channel.to_ascii_lowercase();
            let is_member = self
                .channels
                .get(&key)
                .map(|ch| ch.members.contains(&id))
                .unwrap_or(false);
            if is_member {
                let line = format!(":{} PART {}", Self::prefix(&nick), channel);
                self.broadcast(&key, &line, None);
                if let Some(ch) = self.channels.get_mut(&key) {
                    ch.members.retain(|m| *m != id);
                }
            }
        }
    }

    fn cmd_privmsg(&mut self, id: u64, params: &[String], notice: bool) {
        if !self.is_registered(id) {
            return;
        }
        let target = match params.first() {
            Some(t) if !t.is_empty() => t.clone(),
            _ => return,
        };
        let text = params.get(1).cloned().unwrap_or_default();
        let from = match self.nick_of(id) {
            Some(n) => n,
            None => return,
        };
        let cmd = if notice { "NOTICE" } else { "PRIVMSG" };
        let line = format!(":{} {} {} :{}", Self::prefix(&from), cmd, target, text);
        if target.starts_with('#') {
            let key = target.to_ascii_lowercase();
            self.broadcast(&key, &line, Some(id));
        } else if let Some(dst) = self.find_client(&target) {
            self.send(dst, &line);
        }
    }

    fn cmd_mode(&mut self, id: u64, params: &[String]) {
        let nick = self.nick_of(id).unwrap_or_else(|| "*".to_string());
        if let Some(target) = params.first() {
            if target.starts_with('#') && params.len() == 1 {
                self.snum(id, 324, &nick, &format!("{target} +nt"));
            }
        }
    }

    fn cmd_who(&mut self, id: u64, params: &[String]) {
        let nick = self.nick_of(id).unwrap_or_else(|| "*".to_string());
        let srv = self.cfg.server_name.clone();
        if let Some(channel) = params.first() {
            if channel.starts_with('#') {
                let key = channel.to_ascii_lowercase();
                for member in self.member_names(&key) {
                    self.snum(
                        id,
                        352,
                        &nick,
                        &format!("{channel} {member} localhost {srv} {member} H :0 erc-llm"),
                    );
                }
                self.snum(id, 315, &nick, &format!("{channel} :End of /WHO list."));
            }
        }
    }

    fn cmd_topic(&mut self, id: u64, params: &[String]) {
        let nick = self.nick_of(id).unwrap_or_else(|| "*".to_string());
        let channel = match params.first() {
            Some(c) => c.clone(),
            None => return,
        };
        let key = channel.to_ascii_lowercase();
        if !self.channels.contains_key(&key) {
            return;
        }
        if params.len() > 1 {
            // Set topic + broadcast.
            let topic = params[1].clone();
            if let Some(ch) = self.channels.get_mut(&key) {
                ch.topic = topic.clone();
            }
            let line = format!(":{} TOPIC {} :{}", Self::prefix(&nick), channel, topic);
            self.broadcast(&key, &line, None);
        } else {
            let topic = self
                .channels
                .get(&key)
                .map(|ch| ch.topic.clone())
                .unwrap_or_default();
            self.snum(id, 332, &nick, &format!("{channel} :{topic}"));
        }
    }
}

/// IRC-friendly local timestamp: `%Y-%m-%dT%H:%M:%S%z`.
///
/// We avoid pulling in `chrono`; this is a best-effort UTC-based stamp using
/// only `std`. The exact value is cosmetic (numeric 003 text only).
fn now_iso8601() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    // Civil-from-days (Howard Hinnant's algorithm) for UTC.
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let (hh, mm, ss) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}-{m:02}-{d:02}T{hh:02}:{mm:02}:{ss:02}+0000")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_nick_rules() {
        assert!(ServerState::valid_nick("alice"));
        assert!(ServerState::valid_nick("a_b.c|d^e`f{g}"));
        assert!(!ServerState::valid_nick("")); // empty
        assert!(!ServerState::valid_nick("1abc")); // must start alpha
        assert!(!ServerState::valid_nick("-abc")); // must start alpha
        assert!(!ServerState::valid_nick("ab cd")); // no space
        let too_long = "a".repeat(65);
        assert!(!ServerState::valid_nick(&too_long));
        assert!(ServerState::valid_nick(&"a".repeat(64)));
    }

    #[test]
    fn now_is_well_formed() {
        let s = now_iso8601();
        // YYYY-MM-DDTHH:MM:SS+0000
        assert_eq!(s.len(), 24);
        assert_eq!(&s[4..5], "-");
        assert_eq!(&s[10..11], "T");
        assert!(s.ends_with("+0000"));
    }
}
