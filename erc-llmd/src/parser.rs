//! IRC line parser, replicating `erc-llm-ircd--parse` from erc-llm-ircd.el.
//!
//! Behaviour (must match the .el exactly):
//!   - Strip trailing `\r`/`\n` from the line.
//!   - An optional leading `:prefix` (up to the first space) is split off.
//!   - The trailing parameter is everything after the first ` :` (space-colon).
//!   - If the remainder (after prefix removal) itself begins with `:`, the
//!     whole remainder is the trailing parameter and there are no middle
//!     params (mirrors the .el's "whole remainder is trailing" branch).
//!   - The command is the first whitespace-delimited token, upcased.
//!   - Middle params are the remaining whitespace-delimited tokens (empty
//!     tokens collapsed, matching Emacs `split-string` with OMIT-NULLS).
//!   - Returns `None` when there is no command.

/// A parsed IRC message.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Message {
    /// The optional source prefix (without the leading `:`).
    pub prefix: Option<String>,
    /// The command, upcased.
    pub command: String,
    /// Parameters; the trailing parameter (if any) is the last element.
    pub params: Vec<String>,
}

/// Parse a single raw IRC line into a [`Message`].
///
/// Returns `None` for an empty line or one with no command token.
pub fn parse(line: &str) -> Option<Message> {
    // Strip trailing CR/LF (the .el trims "[\r\n]+" off the right).
    let mut s: &str = line.trim_end_matches(['\r', '\n']);

    // Optional leading :prefix up to the first space.
    let mut prefix: Option<String> = None;
    if let Some(rest) = s.strip_prefix(':') {
        if let Some(sp) = rest.find(' ') {
            prefix = Some(rest[..sp].to_string());
            // Advance past the prefix and its trailing space.
            s = &rest[sp + 1..];
        }
        // If there is no space after ':', the .el leaves `s` unchanged
        // (string-search returns nil -> no prefix split). We mirror that by
        // NOT consuming: fall through with the original `s`.
    }

    // Trailing parameter: everything after the first " :".
    let mut trail: Option<String> = None;
    if let Some(tp) = s.find(" :") {
        trail = Some(s[tp + 2..].to_string());
        s = &s[..tp];
    }
    // Whole remainder is trailing if it begins with ':'.
    if let Some(rest) = s.strip_prefix(':') {
        trail = Some(rest.to_string());
        s = "";
    }

    // Tokenise the middle (split on spaces, omit empty tokens).
    let mut toks = s.split(' ').filter(|t| !t.is_empty());
    let command = toks.next()?.to_uppercase();
    let mut params: Vec<String> = toks.map(|t| t.to_string()).collect();
    if let Some(t) = trail {
        params.push(t);
    }

    Some(Message {
        prefix,
        command,
        params,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn m(prefix: Option<&str>, command: &str, params: &[&str]) -> Message {
        Message {
            prefix: prefix.map(|p| p.to_string()),
            command: command.to_string(),
            params: params.iter().map(|p| p.to_string()).collect(),
        }
    }

    #[test]
    fn empty_line_is_none() {
        assert_eq!(parse(""), None);
        assert_eq!(parse("\r\n"), None);
        assert_eq!(parse("   "), None);
    }

    #[test]
    fn simple_command_no_params() {
        assert_eq!(parse("PING"), Some(m(None, "PING", &[])));
    }

    #[test]
    fn command_is_upcased() {
        assert_eq!(parse("ping"), Some(m(None, "PING", &[])));
        assert_eq!(parse("nick alice"), Some(m(None, "NICK", &["alice"])));
    }

    #[test]
    fn middle_params() {
        assert_eq!(
            parse("USER alice 0 * realname"),
            Some(m(None, "USER", &["alice", "0", "*", "realname"]))
        );
    }

    #[test]
    fn trailing_param() {
        assert_eq!(
            parse("PRIVMSG #partyline :hello world"),
            Some(m(None, "PRIVMSG", &["#partyline", "hello world"]))
        );
    }

    #[test]
    fn trailing_param_with_colons_inside() {
        // Only the FIRST " :" splits; later colons stay in the trailing text.
        assert_eq!(
            parse("PRIVMSG #c :a : b : c"),
            Some(m(None, "PRIVMSG", &["#c", "a : b : c"]))
        );
    }

    #[test]
    fn leading_prefix() {
        assert_eq!(
            parse(":nick!nick@localhost PRIVMSG #c :hi"),
            Some(m(Some("nick!nick@localhost"), "PRIVMSG", &["#c", "hi"]))
        );
    }

    #[test]
    fn prefix_with_no_trailing() {
        assert_eq!(
            parse(":srv MODE #c +nt"),
            Some(m(Some("srv"), "MODE", &["#c", "+nt"]))
        );
    }

    #[test]
    fn whole_remainder_is_trailing() {
        // After the command, a param that itself starts with ':' becomes the
        // single trailing param (the .el's "whole remainder is trailing").
        assert_eq!(
            parse("QUIT :Client quit"),
            Some(m(None, "QUIT", &["Client quit"]))
        );
    }

    #[test]
    fn empty_trailing_param() {
        // "CAP REQ :" -> trailing param is the empty string.
        assert_eq!(parse("CAP REQ :"), Some(m(None, "CAP", &["REQ", ""])));
    }

    #[test]
    fn user_with_trailing_realname() {
        // Mirrors what the partyline client sends.
        assert_eq!(
            parse("USER alice 0 * :alice erc-llm agent"),
            Some(m(None, "USER", &["alice", "0", "*", "alice erc-llm agent"]))
        );
    }

    #[test]
    fn collapses_repeated_spaces() {
        // Emacs split-string with OMIT-NULLS collapses runs of spaces.
        assert_eq!(parse("NICK   alice"), Some(m(None, "NICK", &["alice"])));
    }

    #[test]
    fn strips_trailing_crlf_only() {
        assert_eq!(
            parse("JOIN #partyline\r\n"),
            Some(m(None, "JOIN", &["#partyline"]))
        );
    }

    #[test]
    fn cap_ls() {
        assert_eq!(parse("CAP LS 302"), Some(m(None, "CAP", &["LS", "302"])));
    }
}
