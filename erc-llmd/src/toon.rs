//! TOON (Token-Oriented Object Notation) v3.0 codec — std-only, zero runtime deps.
//!
//! Implements the normative subset of the TOON v3.0 specification
//! (`toon-spec/SPEC.md`, sections 1-16 + 19): a `Value` data model that
//! preserves array and object key order (§2), a strict-mode-aware `decode`,
//! and a deterministic `encode`.
//!
//! ## Number policy (§2 / §4)
//!
//! Numbers are carried as an `f64` plus the *exact source text* observed at
//! decode time (`Value::Number`). This lets the decoder round-trip oddities
//! like `1.5000` (value `1.5`) while still reporting the canonical numeric
//! value, and lets the encoder reproduce the canonical decimal form (no
//! exponent, no trailing zeros, `-0` → `0`) matching the reference
//! (JavaScript) `Number.prototype.toString` shortest-round-trip behavior.
//! Tokens with forbidden leading zeros (`05`, `-0001`) stay strings (§2).
//!
//! ## Key folding / path expansion (§13.4)
//!
//! Both default to **off** (dotted keys are literal). The `"safe"` modes are
//! implemented for completeness (encoder `key_folding`, decoder `expand_paths`).
//!
//! The shipped library and binary have **zero** third-party dependencies; the
//! conformance harness in `tests/` adds `serde_json` as a *dev-dependency only*
//! to parse the language-agnostic fixture oracle.

use std::fmt::Write as _;

/// A JSON-equivalent value. Object key order and array order are preserved.
#[derive(Debug, Clone)]
pub enum Value {
    Null,
    Bool(bool),
    /// Numeric value plus its canonical source text (see module docs).
    Number(Number),
    String(String),
    Array(Vec<Value>),
    /// Insertion-ordered map of `(key, value)` pairs.
    Object(Vec<(String, Value)>),
}

/// A number: the `f64` value plus the exact textual representation to emit.
#[derive(Debug, Clone)]
pub struct Number {
    value: f64,
    text: String,
}

impl Number {
    /// Build a `Number` from an `f64`, computing its canonical TOON text (§2).
    pub fn from_f64(v: f64) -> Self {
        let text = canonical_number(v);
        Number { value: v, text }
    }

    /// Build a `Number` from an already-canonical text and its parsed value.
    fn from_parts(value: f64, text: String) -> Self {
        Number { value, text }
    }

    /// The numeric value as `f64`.
    pub fn as_f64(&self) -> f64 {
        self.value
    }

    /// The canonical TOON text for this number.
    pub fn text(&self) -> &str {
        &self.text
    }
}

impl Value {
    /// Convenience constructor for a number from an `f64`.
    pub fn number(v: f64) -> Value {
        Value::Number(Number::from_f64(v))
    }
}

/// Decode/encode error. `ToonError::message` carries a human-readable reason.
#[derive(Debug, Clone)]
pub struct ToonError {
    pub message: String,
}

impl ToonError {
    fn new(msg: impl Into<String>) -> Self {
        ToonError {
            message: msg.into(),
        }
    }
}

impl std::fmt::Display for ToonError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for ToonError {}

type Result<T> = std::result::Result<T, ToonError>;

/// Active delimiter for an array scope.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Delim {
    Comma,
    Tab,
    Pipe,
}

impl Delim {
    fn ch(self) -> char {
        match self {
            Delim::Comma => ',',
            Delim::Tab => '\t',
            Delim::Pipe => '|',
        }
    }
}

// ===========================================================================
// Encoding
// ===========================================================================

/// Key-folding mode (encoder, §13.4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KeyFolding {
    Off,
    Safe,
}

/// Encoder options.
#[derive(Debug, Clone)]
pub struct EncodeOptions {
    /// Spaces per indentation level (default 2).
    pub indent: usize,
    /// Document delimiter (default comma).
    pub delimiter: Delimiter,
    /// Key folding mode (default off).
    pub key_folding: KeyFolding,
    /// Max segments to fold; `None` = infinity (default).
    pub flatten_depth: Option<usize>,
}

/// Public delimiter selection for encoding.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Delimiter {
    Comma,
    Tab,
    Pipe,
}

impl Delimiter {
    fn to_delim(self) -> Delim {
        match self {
            Delimiter::Comma => Delim::Comma,
            Delimiter::Tab => Delim::Tab,
            Delimiter::Pipe => Delim::Pipe,
        }
    }
}

impl Default for EncodeOptions {
    fn default() -> Self {
        EncodeOptions {
            indent: 2,
            delimiter: Delimiter::Comma,
            key_folding: KeyFolding::Off,
            flatten_depth: None,
        }
    }
}

/// Encode a [`Value`] to a TOON string (no trailing newline; §12).
pub fn encode(value: &Value, opts: &EncodeOptions) -> String {
    let doc_delim = opts.delimiter.to_delim();
    let mut out = String::new();
    let enc = Encoder {
        indent: opts.indent,
        doc_delim,
        key_folding: opts.key_folding,
        flatten_depth: opts.flatten_depth,
    };
    enc.encode_root(value, &mut out);
    out
}

struct Encoder {
    indent: usize,
    doc_delim: Delim,
    key_folding: KeyFolding,
    flatten_depth: Option<usize>,
}

/// Result of attempting to fold a single-key chain (§13.4).
enum FoldOutcome<'v> {
    /// Fold into `key`; encode `leaf` (further folding controlled by `leaf_fold`).
    Fold {
        key: String,
        leaf: &'v Value,
        leaf_fold: bool,
    },
    /// Full-chain collision: emit this field and its whole subtree unfolded.
    NoFoldSubtree,
    /// Not a foldable chain; encode normally (folding still allowed deeper).
    NotApplicable,
}

impl Encoder {
    fn pad(&self, depth: usize) -> String {
        " ".repeat(self.indent * depth)
    }

    fn encode_root(&self, value: &Value, out: &mut String) {
        match value {
            Value::Object(fields) => {
                self.encode_object_fields(fields, 0, out);
            }
            Value::Array(items) => {
                self.encode_array(None, items, 0, out);
            }
            other => {
                out.push_str(&self.encode_primitive(other, self.doc_delim));
            }
        }
    }

    /// Encode object fields at `depth`, joined by newlines. Applies key folding
    /// when `fold` is true (disabled for subtrees of an abandoned fold chain).
    fn encode_object_fields(&self, fields: &[(String, Value)], depth: usize, out: &mut String) {
        self.encode_object_fields_inner(fields, depth, self.key_folding == KeyFolding::Safe, out);
    }

    fn encode_object_fields_inner(
        &self,
        fields: &[(String, Value)],
        depth: usize,
        fold: bool,
        out: &mut String,
    ) {
        let pad = self.pad(depth);
        let mut first = true;
        for (k, v) in fields {
            if !first {
                out.push('\n');
            }
            first = false;
            out.push_str(&pad);
            if fold {
                match self.try_fold(k, v, fields) {
                    FoldOutcome::Fold {
                        key,
                        leaf,
                        leaf_fold,
                    } => {
                        self.encode_field(&key, leaf, depth, leaf_fold, out);
                        continue;
                    }
                    FoldOutcome::NoFoldSubtree => {
                        // Collision: emit this field and its subtree unfolded.
                        self.encode_field(k, v, depth, false, out);
                        continue;
                    }
                    FoldOutcome::NotApplicable => {}
                }
            }
            self.encode_field(k, v, depth, fold, out);
        }
    }

    /// Encode a single `key: value` field (value may open nested structure).
    /// `fold` controls whether nested objects may be folded (§13.4).
    fn encode_field(&self, key: &str, value: &Value, depth: usize, fold: bool, out: &mut String) {
        let key_tok = encode_key(key);
        match value {
            Value::Array(items) => {
                self.encode_array(Some(&key_tok), items, depth, out);
            }
            Value::Object(inner) => {
                if inner.is_empty() {
                    out.push_str(&key_tok);
                    out.push(':');
                } else {
                    out.push_str(&key_tok);
                    out.push(':');
                    out.push('\n');
                    self.encode_object_fields_inner(inner, depth + 1, fold, out);
                }
            }
            primitive => {
                out.push_str(&key_tok);
                out.push_str(": ");
                out.push_str(&self.encode_primitive(primitive, self.doc_delim));
            }
        }
    }

    /// Try to fold a single-key chain starting at `(key, value)` (§13.4 safe).
    fn try_fold<'v>(
        &self,
        key: &str,
        value: &'v Value,
        siblings: &[(String, Value)],
    ) -> FoldOutcome<'v> {
        let max = self.flatten_depth.unwrap_or(usize::MAX);
        if max < 2 {
            return FoldOutcome::NotApplicable;
        }
        if !is_identifier_segment(key) {
            return FoldOutcome::NotApplicable;
        }
        // Compute the maximal eligible chain (ignoring flattenDepth) to detect
        // a full-chain collision, and the depth-limited fold separately.
        let mut full_segments = vec![key.to_string()];
        let mut cur_full = value;
        loop {
            match cur_full {
                Value::Object(inner) if inner.len() == 1 => {
                    let (ck, cv) = &inner[0];
                    if !is_identifier_segment(ck) {
                        break;
                    }
                    full_segments.push(ck.clone());
                    cur_full = cv;
                }
                _ => break,
            }
        }
        if full_segments.len() < 2 {
            return FoldOutcome::NotApplicable;
        }
        // Collision avoidance (§13.4 rule 3): the full folded key MUST NOT equal
        // a sibling literal key. If it would, abandon folding for this chain.
        let full_key = full_segments.join(".");
        if siblings.iter().any(|(sk, _)| sk == &full_key) {
            return FoldOutcome::NoFoldSubtree;
        }
        // Depth-limited fold: take min(chain length, flattenDepth) segments.
        let d = full_segments.len().min(max);
        let mut cur = value;
        for _ in 1..d {
            if let Value::Object(inner) = cur {
                cur = &inner[0].1;
            }
        }
        let folded = full_segments[..d].join(".");
        // If we folded the entire chain, the leaf may still be folded further
        // (it is a primitive/array/empty-object). If partial (d < n), the
        // remaining structure MUST be emitted as normal nesting (unfolded).
        let leaf_fold = d >= full_segments.len();
        FoldOutcome::Fold {
            key: folded,
            leaf: cur,
            leaf_fold,
        }
    }

    /// Encode an array with optional key prefix at `depth`.
    fn encode_array(&self, key_tok: Option<&str>, items: &[Value], depth: usize, out: &mut String) {
        let active = self.doc_delim;
        // Empty array: `key[0]:` / `[0]:`.
        if items.is_empty() {
            self.write_header(key_tok, 0, active, None, out);
            return;
        }
        // Tabular detection (§9.3).
        if let Some(fields) = tabular_fields(items) {
            self.write_header(key_tok, items.len(), active, Some(&fields), out);
            for item in items {
                out.push('\n');
                out.push_str(&self.pad(depth + 1));
                self.encode_tabular_row(item, &fields, active, out);
            }
            return;
        }
        // Inline primitive array (§9.1): all primitives.
        if items.iter().all(is_primitive) {
            self.write_header(key_tok, items.len(), active, None, out);
            out.push(' ');
            let mut first = true;
            for item in items {
                if !first {
                    out.push(active.ch());
                }
                first = false;
                out.push_str(&self.encode_primitive(item, active));
            }
            return;
        }
        // Expanded list (§9.2 / §9.4).
        self.write_header(key_tok, items.len(), active, None, out);
        for item in items {
            out.push('\n');
            self.encode_list_item(item, depth + 1, out);
        }
    }

    /// Like [`Self::encode_array`] but for a non-tabular array that is the
    /// FIRST field of a list-item object: the header is emitted inline on the
    /// hyphen line (at `depth`), and expanded items live at `depth + 2` (§10).
    fn encode_array_first_field(
        &self,
        key_tok: Option<&str>,
        items: &[Value],
        depth: usize,
        out: &mut String,
    ) {
        let active = self.doc_delim;
        if items.is_empty() {
            self.write_header(key_tok, 0, active, None, out);
            return;
        }
        // (Tabular-first is handled separately by the caller.)
        if items.iter().all(is_primitive) {
            self.write_header(key_tok, items.len(), active, None, out);
            out.push(' ');
            let mut first = true;
            for item in items {
                if !first {
                    out.push(active.ch());
                }
                first = false;
                out.push_str(&self.encode_primitive(item, active));
            }
            return;
        }
        // Expanded list at depth+2 relative to the hyphen line.
        self.write_header(key_tok, items.len(), active, None, out);
        for item in items {
            out.push('\n');
            self.encode_list_item(item, depth + 2, out);
        }
    }

    /// Write an array header: `key[N<delim?>]{fields}?:` (no trailing newline).
    fn write_header(
        &self,
        key_tok: Option<&str>,
        n: usize,
        active: Delim,
        fields: Option<&[String]>,
        out: &mut String,
    ) {
        if let Some(k) = key_tok {
            out.push_str(k);
        }
        out.push('[');
        let _ = write!(out, "{n}");
        match active {
            Delim::Comma => {}
            Delim::Tab => out.push('\t'),
            Delim::Pipe => out.push('|'),
        }
        out.push(']');
        if let Some(fs) = fields {
            out.push('{');
            let mut first = true;
            for f in fs {
                if !first {
                    out.push(active.ch());
                }
                first = false;
                out.push_str(&encode_key(f));
            }
            out.push('}');
        }
        out.push(':');
    }

    fn encode_tabular_row(&self, item: &Value, fields: &[String], active: Delim, out: &mut String) {
        let obj = match item {
            Value::Object(o) => o,
            _ => unreachable!("tabular_fields guarantees objects"),
        };
        let mut first = true;
        for f in fields {
            if !first {
                out.push(active.ch());
            }
            first = false;
            let v = obj
                .iter()
                .find(|(k, _)| k == f)
                .map(|(_, v)| v)
                .expect("tabular_fields guarantees key presence");
            out.push_str(&self.encode_primitive(v, active));
        }
    }

    /// Encode one expanded list item at `depth` (line begins with the pad).
    fn encode_list_item(&self, item: &Value, depth: usize, out: &mut String) {
        let pad = self.pad(depth);
        match item {
            Value::Object(fields) => {
                if fields.is_empty() {
                    out.push_str(&pad);
                    out.push('-');
                    return;
                }
                // First field on the hyphen line.
                let (fk, fv) = &fields[0];
                let first_is_tabular =
                    matches!(fv, Value::Array(items) if tabular_fields(items).is_some());
                out.push_str(&pad);
                out.push_str("- ");
                if first_is_tabular {
                    // Header on hyphen line; rows at depth+2; other fields depth+1.
                    if let Value::Array(items) = fv {
                        let key_tok = encode_key(fk);
                        let fs = tabular_fields(items).unwrap();
                        self.write_header(
                            Some(&key_tok),
                            items.len(),
                            self.doc_delim,
                            Some(&fs),
                            out,
                        );
                        for it in items {
                            out.push('\n');
                            out.push_str(&self.pad(depth + 2));
                            self.encode_tabular_row(it, &fs, self.doc_delim, out);
                        }
                    }
                } else if let Value::Array(items) = fv {
                    // Non-tabular array as first field: header inline on the
                    // hyphen line; expanded list items / nested arrays go at
                    // depth+2 relative to the hyphen line (§10).
                    let key_tok = encode_key(fk);
                    self.encode_array_first_field(Some(&key_tok), items, depth, out);
                } else {
                    // Encode first field inline at the hyphen's content column.
                    self.encode_field_at(fk, fv, depth, out);
                }
                // Remaining fields at depth+1.
                for (k, v) in &fields[1..] {
                    out.push('\n');
                    out.push_str(&self.pad(depth + 1));
                    self.encode_field_at(k, v, depth + 1, out);
                }
            }
            Value::Array(inner) => {
                // `- [M]: ...` for primitive arrays, or nested expanded forms.
                out.push_str(&pad);
                out.push_str("- ");
                self.encode_inline_array_item(inner, depth, out);
            }
            primitive => {
                out.push_str(&pad);
                out.push_str("- ");
                out.push_str(&self.encode_primitive(primitive, self.doc_delim));
            }
        }
    }

    /// Encode `[M]: ...` array body that follows a `- ` marker at `depth`.
    fn encode_inline_array_item(&self, inner: &[Value], depth: usize, out: &mut String) {
        let active = self.doc_delim;
        if inner.is_empty() {
            self.write_header(None, 0, active, None, out);
            return;
        }
        if let Some(fields) = tabular_fields(inner) {
            self.write_header(None, inner.len(), active, Some(&fields), out);
            for it in inner {
                out.push('\n');
                out.push_str(&self.pad(depth + 2));
                self.encode_tabular_row(it, &fields, active, out);
            }
            return;
        }
        if inner.iter().all(is_primitive) {
            self.write_header(None, inner.len(), active, None, out);
            out.push(' ');
            let mut first = true;
            for it in inner {
                if !first {
                    out.push(active.ch());
                }
                first = false;
                out.push_str(&self.encode_primitive(it, active));
            }
            return;
        }
        // Nested non-uniform: header then deeper items.
        self.write_header(None, inner.len(), active, None, out);
        for it in inner {
            out.push('\n');
            self.encode_list_item(it, depth + 1, out);
        }
    }

    /// Encode a field that begins at the given content `depth` (used for the
    /// first field of a list item, where nested objects go to depth+2 and the
    /// content column already equals `depth+1`'s worth of padding written by
    /// the caller). Arrays/objects render relative to `depth`.
    fn encode_field_at(&self, key: &str, value: &Value, depth: usize, out: &mut String) {
        let key_tok = encode_key(key);
        match value {
            Value::Array(items) => {
                self.encode_array(Some(&key_tok), items, depth, out);
            }
            Value::Object(inner) => {
                if inner.is_empty() {
                    out.push_str(&key_tok);
                    out.push(':');
                } else {
                    out.push_str(&key_tok);
                    out.push(':');
                    out.push('\n');
                    self.encode_object_fields(inner, depth + 1, out);
                }
            }
            primitive => {
                out.push_str(&key_tok);
                out.push_str(": ");
                out.push_str(&self.encode_primitive(primitive, self.doc_delim));
            }
        }
    }

    fn encode_primitive(&self, value: &Value, active: Delim) -> String {
        match value {
            Value::Null => "null".to_string(),
            Value::Bool(true) => "true".to_string(),
            Value::Bool(false) => "false".to_string(),
            Value::Number(n) => n.text().to_string(),
            Value::String(s) => encode_string_value(s, active),
            Value::Array(_) | Value::Object(_) => {
                // Should not be reached for primitive contexts.
                String::new()
            }
        }
    }
}

fn is_primitive(v: &Value) -> bool {
    matches!(
        v,
        Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_)
    )
}

/// Return the tabular field list if `items` qualify for tabular form (§9.3):
/// non-empty, every element an object, all with the same key set, all values
/// primitive. Field order follows the first object's encounter order.
fn tabular_fields(items: &[Value]) -> Option<Vec<String>> {
    if items.is_empty() {
        return None;
    }
    let first = match &items[0] {
        Value::Object(o) if !o.is_empty() => o,
        _ => return None,
    };
    let fields: Vec<String> = first.iter().map(|(k, _)| k.clone()).collect();
    for item in items {
        let obj = match item {
            Value::Object(o) => o,
            _ => return None,
        };
        if obj.len() != fields.len() {
            return None;
        }
        for (k, v) in obj {
            if !fields.iter().any(|f| f == k) {
                return None;
            }
            if !is_primitive(v) {
                return None;
            }
        }
    }
    Some(fields)
}

/// Identifier segment per §1.9: `^[A-Za-z_][A-Za-z0-9_]*$` (no dots).
fn is_identifier_segment(s: &str) -> bool {
    let mut chars = s.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

/// Unquoted-key pattern per §7.3: `^[A-Za-z_][A-Za-z0-9_.]*$`.
fn is_unquoted_key(s: &str) -> bool {
    let mut chars = s.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '.')
}

/// Encode an object key / field name (§7.3): unquoted if eligible, else quoted.
fn encode_key(key: &str) -> String {
    if is_unquoted_key(key) {
        key.to_string()
    } else {
        quote_string(key)
    }
}

/// Quote and escape a string per §7.1.
fn quote_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            other => out.push(other),
        }
    }
    out.push('"');
    out
}

/// Decide whether a string value needs quoting (§7.2) given the active
/// delimiter for its context, then emit quoted-or-bare.
fn encode_string_value(s: &str, active: Delim) -> String {
    if needs_quoting(s, active) {
        quote_string(s)
    } else {
        s.to_string()
    }
}

/// §7.2 quoting predicate. `active` is the delimiter relevant to this context
/// (active delimiter inside arrays, document delimiter for object values).
fn needs_quoting(s: &str, active: Delim) -> bool {
    if s.is_empty() {
        return true;
    }
    // Leading/trailing whitespace.
    let bytes = s.as_bytes();
    if bytes[0] == b' ' || bytes[bytes.len() - 1] == b' ' {
        return true;
    }
    if s.starts_with(char::is_whitespace) || s.ends_with(char::is_whitespace) {
        return true;
    }
    // Reserved literals.
    if s == "true" || s == "false" || s == "null" {
        return true;
    }
    // Numeric-like (§7.2).
    if looks_numeric(s) || is_leading_zero_decimal(s) {
        return true;
    }
    // Structural / control characters.
    for c in s.chars() {
        match c {
            ':' | '"' | '\\' | '[' | ']' | '{' | '}' | '\n' | '\r' | '\t' => return true,
            _ => {}
        }
    }
    // Active delimiter present.
    if s.contains(active.ch()) {
        return true;
    }
    // Leading hyphen at position 0.
    if s.starts_with('-') {
        return true;
    }
    false
}

/// `/^-?\d+(?:\.\d+)?(?:e[+-]?\d+)?$/i`
fn looks_numeric(s: &str) -> bool {
    let b = s.as_bytes();
    let mut i = 0;
    if i < b.len() && b[i] == b'-' {
        i += 1;
    }
    let int_start = i;
    while i < b.len() && b[i].is_ascii_digit() {
        i += 1;
    }
    if i == int_start {
        return false;
    }
    if i < b.len() && b[i] == b'.' {
        i += 1;
        let frac_start = i;
        while i < b.len() && b[i].is_ascii_digit() {
            i += 1;
        }
        if i == frac_start {
            return false;
        }
    }
    if i < b.len() && (b[i] == b'e' || b[i] == b'E') {
        i += 1;
        if i < b.len() && (b[i] == b'+' || b[i] == b'-') {
            i += 1;
        }
        let exp_start = i;
        while i < b.len() && b[i].is_ascii_digit() {
            i += 1;
        }
        if i == exp_start {
            return false;
        }
    }
    i == b.len()
}

/// `/^0\d+$/` — leading-zero decimal like "05".
fn is_leading_zero_decimal(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() >= 2 && b[0] == b'0' && b[1..].iter().all(|c| c.is_ascii_digit())
}

// ---------------------------------------------------------------------------
// Canonical number formatting (§2)
// ---------------------------------------------------------------------------

/// Produce the canonical TOON decimal form of `v` (§2): no exponent, no
/// trailing zeros, `-0` → `0`. Matches the reference (JS) shortest round-trip.
fn canonical_number(v: f64) -> String {
    if v == 0.0 {
        // Covers -0.0 too.
        return "0".to_string();
    }
    if !v.is_finite() {
        // §3 maps NaN/±Inf to null at the value layer; defensive fallback.
        return "null".to_string();
    }
    // Rust's `{}` for f64 yields the shortest representation that round-trips,
    // but may use exponent for very large/small magnitudes. Detect and expand.
    let shortest = format!("{v}");
    if !shortest.contains('e') && !shortest.contains('E') {
        return strip_trailing_zeros(&shortest);
    }
    expand_exponent(&shortest)
}

/// Remove redundant trailing zeros in the fractional part and a trailing dot.
fn strip_trailing_zeros(s: &str) -> String {
    if !s.contains('.') {
        return s.to_string();
    }
    let trimmed = s.trim_end_matches('0');
    let trimmed = trimmed.trim_end_matches('.');
    trimmed.to_string()
}

/// Expand a `mantissa e exp` string into plain decimal notation.
fn expand_exponent(s: &str) -> String {
    let (mantissa, exp_str) = match s.split_once(['e', 'E']) {
        Some((m, e)) => (m, e),
        None => return s.to_string(),
    };
    let exp: i64 = exp_str.parse().unwrap_or(0);
    let negative = mantissa.starts_with('-');
    let mantissa = mantissa.trim_start_matches('-');
    let (int_part, frac_part) = match mantissa.split_once('.') {
        Some((i, f)) => (i.to_string(), f.to_string()),
        None => (mantissa.to_string(), String::new()),
    };
    let digits: String = format!("{int_part}{frac_part}");
    // Decimal point originally sits after int_part.len() digits; shift by exp.
    let point_pos = int_part.len() as i64 + exp;
    let mut result = String::new();
    if point_pos <= 0 {
        result.push_str("0.");
        for _ in 0..(-point_pos) {
            result.push('0');
        }
        result.push_str(&digits);
    } else if (point_pos as usize) >= digits.len() {
        result.push_str(&digits);
        for _ in 0..(point_pos as usize - digits.len()) {
            result.push('0');
        }
    } else {
        let (a, b) = digits.split_at(point_pos as usize);
        result.push_str(a);
        result.push('.');
        result.push_str(b);
    }
    let result = strip_trailing_zeros(&result);
    if negative && result != "0" {
        format!("-{result}")
    } else {
        result
    }
}

// ===========================================================================
// Decoding
// ===========================================================================

/// Path-expansion mode (decoder, §13.4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExpandPaths {
    Off,
    Safe,
}

/// Decoder options.
#[derive(Debug, Clone)]
pub struct DecodeOptions {
    pub indent: usize,
    pub strict: bool,
    pub expand_paths: ExpandPaths,
}

impl Default for DecodeOptions {
    fn default() -> Self {
        DecodeOptions {
            indent: 2,
            strict: true,
            expand_paths: ExpandPaths::Off,
        }
    }
}

/// Decode a TOON document. `strict` toggles §14 strict-mode checks.
pub fn decode(input: &str, strict: bool) -> Result<Value> {
    decode_with(
        input,
        &DecodeOptions {
            strict,
            ..Default::default()
        },
    )
}

/// Decode with full options.
pub fn decode_with(input: &str, opts: &DecodeOptions) -> Result<Value> {
    let lines = scan_lines(input, opts)?;
    let mut parser = Parser {
        lines: &lines,
        pos: 0,
        opts,
    };
    let value = parser.parse_document()?;
    Ok(value)
}

/// A scanned physical line: indentation depth and trimmed content.
#[derive(Debug, Clone)]
struct Line {
    /// Indentation level = leading_spaces / indent (validated multiple).
    depth: usize,
    /// Content after leading spaces, with trailing whitespace preserved only
    /// where significant (we keep the raw remainder; trimming of values is
    /// handled at token level).
    content: String,
}

/// Split input into non-blank lines with validated indentation (§12, §14.3),
/// while enforcing the strict blank-line-inside-array rule lazily at parse
/// time. Here we keep a parallel record of blank lines for that check by
/// retaining their positions; we instead handle blank lines structurally:
/// blank lines outside arrays are skipped, blank lines inside arrays error.
///
/// To support both, we keep ALL lines (including blanks marked specially) and
/// let the parser decide. We encode a blank line as `depth=usize::MAX`.
fn scan_lines(input: &str, opts: &DecodeOptions) -> Result<Vec<Line>> {
    let mut out = Vec::new();
    for raw in input.split('\n') {
        // Trim a trailing '\r' to tolerate CRLF, though spec mandates LF.
        let raw = raw.strip_suffix('\r').unwrap_or(raw);
        if raw.trim().is_empty() {
            // Blank line marker.
            out.push(Line {
                depth: usize::MAX,
                content: String::new(),
            });
            continue;
        }
        // Count leading spaces; reject tabs in indentation (strict).
        let mut spaces = 0usize;
        for c in raw.chars() {
            match c {
                ' ' => spaces += 1,
                '\t' => {
                    if opts.strict {
                        return Err(ToonError::new("Tabs are not allowed in indentation"));
                    }
                    // Non-strict: stop counting at first non-space.
                    break;
                }
                _ => break,
            }
        }
        let content = raw[spaces..].to_string();
        let depth = if opts.strict {
            if !spaces.is_multiple_of(opts.indent) {
                return Err(ToonError::new(format!(
                    "Indentation must be an exact multiple of {} spaces",
                    opts.indent
                )));
            }
            spaces / opts.indent
        } else {
            spaces / opts.indent
        };
        out.push(Line { depth, content });
    }
    Ok(out)
}

struct Parser<'a> {
    lines: &'a [Line],
    pos: usize,
    opts: &'a DecodeOptions,
}

fn is_blank(line: &Line) -> bool {
    line.depth == usize::MAX
}

impl<'a> Parser<'a> {
    /// Peek the next non-blank line index at or after `pos`, skipping blanks.
    fn next_content_index(&self, from: usize) -> Option<usize> {
        let mut i = from;
        while i < self.lines.len() {
            if !is_blank(&self.lines[i]) {
                return Some(i);
            }
            i += 1;
        }
        None
    }

    fn parse_document(&mut self) -> Result<Value> {
        // Determine root form (§5).
        let first = match self.next_content_index(0) {
            Some(i) => i,
            None => return Ok(Value::Object(vec![])), // empty document
        };
        self.pos = first;
        let line = &self.lines[first];

        // Root array header?
        if let Some(header) = parse_array_header(&line.content)? {
            if header.key.is_none() {
                let depth = line.depth;
                // Advance past the header line before reading the body.
                self.pos = first + 1;
                return self.parse_array_value(&header, depth);
            }
            // Keyed header at root → object.
            return self.parse_object(0);
        }

        // Single primitive? Exactly one non-blank line, not a key-value line.
        // Count non-blank lines.
        let non_blank: Vec<usize> = (0..self.lines.len())
            .filter(|&i| !is_blank(&self.lines[i]))
            .collect();
        if non_blank.len() == 1 {
            let only = &self.lines[non_blank[0]];
            if !is_key_value_line(&only.content)? {
                return parse_primitive_token(&only.content);
            }
        } else if self.opts.strict {
            // Multiple depth-0 lines that are neither headers nor key-value → error (§5).
            let depth0_non_kv: Vec<usize> = non_blank
                .iter()
                .copied()
                .filter(|&i| self.lines[i].depth == 0)
                .filter(|&i| {
                    !is_key_value_line(&self.lines[i].content).unwrap_or(true)
                        && parse_array_header(&self.lines[i].content)
                            .ok()
                            .flatten()
                            .is_none()
                })
                .collect();
            if depth0_non_kv.len() >= 2 {
                return Err(ToonError::new(
                    "Multiple bare primitives at root depth are not a valid TOON document",
                ));
            }
        }

        // Otherwise, object.
        self.parse_object(0)
    }

    /// Parse an object: consume sibling lines at `depth`.
    fn parse_object(&mut self, depth: usize) -> Result<Value> {
        let mut fields: Vec<(String, Value)> = Vec::new();
        let mut quoted_flags: Vec<bool> = Vec::new();
        while let Some(idx) = self.next_content_index(self.pos) {
            let line = &self.lines[idx];
            if line.depth < depth {
                break;
            }
            if line.depth > depth {
                // Should have been consumed by a child; treat as error context.
                return Err(ToonError::new(format!(
                    "Unexpected indentation at depth {} (expected {})",
                    line.depth, depth
                )));
            }
            self.pos = idx + 1;
            let (key, value, was_quoted) = self.parse_field(line, depth)?;
            fields.push((key, value));
            quoted_flags.push(was_quoted);
        }
        let obj = Value::Object(fields);
        if self.opts.expand_paths == ExpandPaths::Safe {
            expand_object(obj, &quoted_flags, self.opts.strict)
        } else {
            Ok(obj)
        }
    }

    /// Parse a single object field from `line` at `depth`. Returns
    /// `(key, value, key_was_quoted)`.
    fn parse_field(&mut self, line: &Line, depth: usize) -> Result<(String, Value, bool)> {
        let content = &line.content;
        // Array header?
        if let Some(header) = parse_array_header(content)? {
            if let Some(k) = &header.key {
                let key = k.text.clone();
                let quoted = k.quoted;
                let value = self.parse_array_value(&header, depth)?;
                return Ok((key, value, quoted));
            }
        }
        // Key-value line.
        let (key, quoted, rest) = parse_key(content)?;
        // `rest` is everything after the colon (may be empty or have a value).
        let rest_trimmed = rest.trim_start();
        if rest_trimmed.is_empty() {
            // Opens a nested object (or empty object).
            let child_idx = self.next_content_index(self.pos);
            match child_idx {
                Some(i) if self.lines[i].depth > depth => {
                    let value = self.parse_object(depth + 1)?;
                    Ok((key, value, quoted))
                }
                _ => Ok((key, Value::Object(vec![]), quoted)),
            }
        } else {
            let value = parse_primitive_token(rest_trimmed)?;
            Ok((key, value, quoted))
        }
    }

    /// Parse an array value given its header. `depth` is the header line depth.
    fn parse_array_value(&mut self, header: &ArrayHeader, depth: usize) -> Result<Value> {
        if let Some(fields) = &header.fields {
            // Tabular array.
            return self.parse_tabular(header, fields, depth);
        }
        if let Some(inline) = &header.inline {
            // Inline primitive array.
            let values = split_delimited(inline, header.delim)?;
            let mut out = Vec::with_capacity(values.len());
            for tok in &values {
                out.push(parse_primitive_token(tok.trim())?);
            }
            if self.opts.strict && out.len() != header.n {
                return Err(ToonError::new(format!(
                    "Expected {} values in inline array, but got {}",
                    header.n,
                    out.len()
                )));
            }
            // Empty inline (`key[0]:`) with no inline text handled below too.
            return Ok(Value::Array(out));
        }
        // No inline text: either empty array or expanded list.
        // Look ahead: are there list items at depth+1 (or deeper)?
        let child = self.next_content_index(self.pos);
        let has_items = matches!(child, Some(i) if self.lines[i].depth > depth
            && self.lines[i].content.starts_with('-'));
        if !has_items {
            // Empty array (count must be 0 in strict mode).
            if self.opts.strict && header.n != 0 {
                return Err(ToonError::new(format!(
                    "Expected {} list array items, but got 0",
                    header.n
                )));
            }
            return Ok(Value::Array(vec![]));
        }
        self.parse_list(header, depth)
    }

    /// Parse a tabular array body. `depth` is the header line depth.
    fn parse_tabular(
        &mut self,
        header: &ArrayHeader,
        fields: &[FieldName],
        depth: usize,
    ) -> Result<Value> {
        let mut rows: Vec<Value> = Vec::new();
        // Rows live at depth+1 (or deeper, for list-item nested tabular).
        let row_depth = match self.next_content_index(self.pos) {
            Some(i) if self.lines[i].depth > depth => self.lines[i].depth,
            _ => depth + 1,
        };
        while let Some(idx) = self.peek_array_member(row_depth)? {
            let line = &self.lines[idx];
            if line.depth != row_depth {
                break;
            }
            // Disambiguation (§9.3): stop if this is a key-value line.
            if is_row_terminator(&line.content, header.delim)? {
                break;
            }
            self.pos = idx + 1;
            let cells = split_delimited(&line.content, header.delim)?;
            if self.opts.strict && cells.len() != fields.len() {
                return Err(ToonError::new(format!(
                    "Expected {} values in row, but got {}",
                    fields.len(),
                    cells.len()
                )));
            }
            let mut obj: Vec<(String, Value)> = Vec::with_capacity(fields.len());
            for (fi, f) in fields.iter().enumerate() {
                let cell = cells.get(fi).map(|s| s.trim()).unwrap_or("");
                obj.push((f.text.clone(), parse_primitive_token(cell)?));
            }
            rows.push(Value::Object(obj));
        }
        if self.opts.strict && rows.len() != header.n {
            return Err(ToonError::new(format!(
                "Expected {} tabular rows, but got {}",
                header.n,
                rows.len()
            )));
        }
        Ok(Value::Array(rows))
    }

    /// Find the next array member line at exactly `member_depth`, enforcing the
    /// strict blank-line-inside-array rule (§14.4). Returns `None` when the
    /// array block ends (a shallower line, terminator, or EOF).
    fn peek_array_member(&mut self, member_depth: usize) -> Result<Option<usize>> {
        // Walk forward from self.pos; if we hit a blank line BEFORE the array
        // ends (i.e., before a shallower content line), strict mode errors.
        let mut i = self.pos;
        let mut saw_blank = false;
        while i < self.lines.len() {
            if is_blank(&self.lines[i]) {
                saw_blank = true;
                i += 1;
                continue;
            }
            let line = &self.lines[i];
            if line.depth < member_depth {
                // Array block ended before this line; trailing blanks are fine.
                return Ok(None);
            }
            // A member (or deeper) line at/after a blank inside the array.
            if saw_blank && self.opts.strict {
                return Err(ToonError::new(
                    "Blank line inside array/tabular block is not allowed in strict mode",
                ));
            }
            return Ok(Some(i));
        }
        Ok(None)
    }

    /// Parse an expanded list array body (§9.2 / §9.4).
    fn parse_list(&mut self, header: &ArrayHeader, depth: usize) -> Result<Value> {
        let mut items: Vec<Value> = Vec::new();
        // Items live at the depth of the first `-` line after the header.
        let item_depth = match self.next_content_index(self.pos) {
            Some(i) if self.lines[i].depth > depth => self.lines[i].depth,
            _ => depth + 1,
        };
        while let Some(idx) = self.peek_array_member(item_depth)? {
            let line = &self.lines[idx];
            if line.depth != item_depth {
                break;
            }
            if !line.content.starts_with('-') {
                break;
            }
            let item = self.parse_list_item(idx, item_depth, header.delim)?;
            items.push(item);
        }
        if self.opts.strict && items.len() != header.n {
            return Err(ToonError::new(format!(
                "Expected {} list array items, but got {}",
                header.n,
                items.len()
            )));
        }
        Ok(Value::Array(items))
    }

    /// Parse one list item starting at `idx` (a `-`-prefixed line) at
    /// `item_depth`. `parent_delim` is the active delimiter inherited for bare
    /// inline arrays (though nested headers re-declare their own).
    fn parse_list_item(
        &mut self,
        idx: usize,
        item_depth: usize,
        _parent_delim: Delim,
    ) -> Result<Value> {
        let line = &self.lines[idx];
        let content = &line.content; // starts with '-'
                                     // Strip the leading '-' and optional single space.
        let after = &content[1..];
        let after = after.strip_prefix(' ').unwrap_or(after);
        let after_trimmed = after.trim();

        // Bare hyphen → empty object list item (§10).
        if after_trimmed.is_empty() {
            self.pos = idx + 1;
            return Ok(Value::Object(vec![]));
        }

        // The content column of the hyphen line is item_depth's indentation + 2.
        // Nested children of an object-first-field appear at item_depth+1 (for
        // siblings) / item_depth+2 (for nested objects under first field).

        // Inline / nested array item: `- [M...]: ...` or `- key[M...]{...}: ...`
        if let Some(header) = parse_array_header(after)? {
            self.pos = idx + 1;
            match &header.key {
                None => {
                    // `- [M]: ...` primitive-or-nested array.
                    return self.parse_inline_or_nested_array(&header, item_depth);
                }
                Some(_) => {
                    // `- key[M]{...}: ...` → object whose first field is array.
                    return self
                        .parse_list_item_object_first_array(after, &header, idx, item_depth);
                }
            }
        }

        // Object with first field on the hyphen line: `- key: ...`
        if is_key_value_line(after)? {
            return self.parse_list_item_object(after, idx, item_depth);
        }

        // Otherwise: a primitive list item.
        self.pos = idx + 1;
        parse_primitive_token(after_trimmed)
    }

    /// `- [M]: ...` — primitive array or nested expanded array.
    fn parse_inline_or_nested_array(
        &mut self,
        header: &ArrayHeader,
        item_depth: usize,
    ) -> Result<Value> {
        if let Some(inline) = &header.inline {
            let values = split_delimited(inline, header.delim)?;
            let mut out = Vec::with_capacity(values.len());
            for tok in &values {
                out.push(parse_primitive_token(tok.trim())?);
            }
            if self.opts.strict && out.len() != header.n {
                return Err(ToonError::new(format!(
                    "Expected {} values in inline array, but got {}",
                    header.n,
                    out.len()
                )));
            }
            return Ok(Value::Array(out));
        }
        if let Some(fields) = &header.fields {
            return self.parse_tabular(header, fields, item_depth);
        }
        // No inline: nested expanded list whose items live deeper.
        let child = self.next_content_index(self.pos);
        let has_items = matches!(child, Some(i) if self.lines[i].depth > item_depth
            && self.lines[i].content.starts_with('-'));
        if !has_items {
            if self.opts.strict && header.n != 0 {
                return Err(ToonError::new(format!(
                    "Expected {} list array items, but got 0",
                    header.n
                )));
            }
            return Ok(Value::Array(vec![]));
        }
        self.parse_list(header, item_depth)
    }

    /// `- key[M]{fields}: ...` (or `- key[M]:`) — list-item object whose first
    /// field is an array. Other fields follow at item_depth+1 (§10).
    fn parse_list_item_object_first_array(
        &mut self,
        after: &str,
        header: &ArrayHeader,
        _idx: usize,
        item_depth: usize,
    ) -> Result<Value> {
        let key = header.key.as_ref().unwrap();
        let key_text = key.text.clone();
        let key_quoted = key.quoted;
        // Parse the array value. For tabular-as-first-field, rows are at +2;
        // for inline, value is on the line; for nested, items deeper.
        let arr = self.parse_inline_or_nested_array_for_field(header, item_depth)?;
        let mut fields: Vec<(String, Value)> = vec![(key_text, arr)];
        let mut quoted_flags: Vec<bool> = vec![key_quoted];
        // Sibling fields at item_depth+1.
        self.collect_list_item_siblings(item_depth, &mut fields, &mut quoted_flags)?;
        let _ = after;
        let obj = Value::Object(fields);
        if self.opts.expand_paths == ExpandPaths::Safe {
            expand_object(obj, &quoted_flags, self.opts.strict)
        } else {
            Ok(obj)
        }
    }

    /// Variant of array parsing used for the first array field of a list-item
    /// object: tabular rows are expected at item_depth+2.
    fn parse_inline_or_nested_array_for_field(
        &mut self,
        header: &ArrayHeader,
        item_depth: usize,
    ) -> Result<Value> {
        if header.inline.is_some() {
            return self.parse_inline_or_nested_array(header, item_depth);
        }
        if let Some(fields) = &header.fields {
            return self.parse_tabular(header, fields, item_depth);
        }
        // Nested expanded list under `- key[M]:` — items deeper than item_depth.
        let child = self.next_content_index(self.pos);
        let has_items = matches!(child, Some(i) if self.lines[i].depth > item_depth
            && self.lines[i].content.starts_with('-'));
        if !has_items {
            if self.opts.strict && header.n != 0 {
                return Err(ToonError::new(format!(
                    "Expected {} list array items, but got 0",
                    header.n
                )));
            }
            return Ok(Value::Array(vec![]));
        }
        self.parse_list(header, item_depth)
    }

    /// `- key: value` (or `- key:` opening nested) — list-item object whose
    /// first field is on the hyphen line. Subsequent fields at item_depth+1,
    /// nested children of the first field at item_depth+2 (§10 / B.5).
    fn parse_list_item_object(
        &mut self,
        after: &str,
        idx: usize,
        item_depth: usize,
    ) -> Result<Value> {
        let mut fields: Vec<(String, Value)> = Vec::new();
        let mut quoted_flags: Vec<bool> = Vec::new();

        // Parse the first field from `after`.
        // It may itself be an array header (handled by caller) — here it's KV.
        let (key, quoted, rest) = parse_key(after)?;
        let rest_trimmed = rest.trim_start();
        self.pos = idx + 1;
        if rest_trimmed.is_empty() {
            // Opens a nested object: its fields are at item_depth+2.
            let child = self.next_content_index(self.pos);
            let value = match child {
                Some(ci) if self.lines[ci].depth > item_depth + 1 => {
                    self.parse_object(self.lines[ci].depth)?
                }
                Some(ci) if self.lines[ci].depth == item_depth + 1 => {
                    // Edge: nested object fields one deeper than hyphen content.
                    self.parse_object(item_depth + 1)?
                }
                _ => Value::Object(vec![]),
            };
            fields.push((key, value));
            quoted_flags.push(quoted);
        } else {
            fields.push((key, parse_primitive_token(rest_trimmed)?));
            quoted_flags.push(quoted);
        }

        // Sibling fields at item_depth+1.
        self.collect_list_item_siblings(item_depth, &mut fields, &mut quoted_flags)?;

        let obj = Value::Object(fields);
        if self.opts.expand_paths == ExpandPaths::Safe {
            expand_object(obj, &quoted_flags, self.opts.strict)
        } else {
            Ok(obj)
        }
    }

    /// Collect sibling fields of a list-item object that appear at
    /// `item_depth + 1`, stopping when indentation drops to item_depth or below.
    fn collect_list_item_siblings(
        &mut self,
        item_depth: usize,
        fields: &mut Vec<(String, Value)>,
        quoted_flags: &mut Vec<bool>,
    ) -> Result<()> {
        let sib_depth = item_depth + 1;
        while let Some(idx) = self.next_content_index(self.pos) {
            let line = &self.lines[idx];
            if line.depth != sib_depth {
                break;
            }
            // A `-` at sibling depth would belong to a parent list, not here.
            if line.content.starts_with('-') {
                break;
            }
            self.pos = idx + 1;
            let (key, value, quoted) = self.parse_field(line, sib_depth)?;
            fields.push((key, value));
            quoted_flags.push(quoted);
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Header / key / token parsing helpers
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
struct KeyTok {
    text: String,
    quoted: bool,
}

#[derive(Debug, Clone)]
struct FieldName {
    text: String,
}

#[derive(Debug, Clone)]
struct ArrayHeader {
    key: Option<KeyTok>,
    n: usize,
    delim: Delim,
    fields: Option<Vec<FieldName>>,
    /// Inline text after `: ` (None if the line ends at the colon).
    inline: Option<String>,
}

/// Try to parse `content` as an array header (§6). Returns `Ok(None)` if the
/// line is not an array header (falls through to key-value parsing). Returns
/// `Err` only for malformed escapes inside quoted key/field segments.
fn parse_array_header(content: &str) -> Result<Option<ArrayHeader>> {
    let bytes = content.as_bytes();
    // Optional key prefix (unquoted or quoted) preceding '['.
    let (key, after_key_idx) = match parse_optional_key_prefix(content)? {
        Some((k, idx)) => (Some(k), idx),
        None => (None, 0),
    };
    // Expect '[' at after_key_idx.
    if after_key_idx >= bytes.len() || bytes[after_key_idx] != b'[' {
        return Ok(None);
    }
    // Find matching ']'.
    let mut j = after_key_idx + 1;
    let close = loop {
        if j >= bytes.len() {
            return Ok(None);
        }
        if bytes[j] == b']' {
            break j;
        }
        j += 1;
    };
    let inner = &content[after_key_idx + 1..close];
    // Parse N and optional delimiter symbol (last char).
    let (n, delim) = match parse_bracket_inner(inner) {
        Some(x) => x,
        None => return Ok(None), // non-integer length → not a header
    };

    // After ']': optional whitespace, then optional `{fields}`, then ':'.
    let mut k = close + 1;
    // Skip whitespace.
    while k < bytes.len() && bytes[k] == b' ' {
        k += 1;
    }
    let mut fields = None;
    if k < bytes.len() && bytes[k] == b'{' {
        // Find matching '}' respecting quotes.
        let (fields_str, end) = match scan_braces(content, k)? {
            Some(x) => x,
            None => return Ok(None),
        };
        fields = Some(parse_field_names(&fields_str, delim)?);
        k = end + 1;
        while k < bytes.len() && bytes[k] == b' ' {
            k += 1;
        }
    }
    // Now must be ':'.
    if k >= bytes.len() || bytes[k] != b':' {
        // Non-whitespace content between ] and : → not a header (§6, §14.2).
        return Ok(None);
    }
    // Inline text after the colon.
    let rest = &content[k + 1..];
    let inline = if rest.is_empty() {
        None
    } else {
        // Exactly one space expected after colon for inline values; tolerate.
        Some(rest.trim_start().to_string())
    };
    // If inline is Some but empty after trim, treat as None.
    let inline = inline.filter(|s| !s.is_empty());

    Ok(Some(ArrayHeader {
        key,
        n,
        delim,
        fields,
        inline,
    }))
}

/// Parse the bracket inner segment: digits then optional tab/pipe symbol.
fn parse_bracket_inner(inner: &str) -> Option<(usize, Delim)> {
    if inner.is_empty() {
        return None;
    }
    let bytes = inner.as_bytes();
    let last = bytes[bytes.len() - 1];
    let (digits, delim) = match last {
        b'\t' => (&inner[..inner.len() - 1], Delim::Tab),
        b'|' => (&inner[..inner.len() - 1], Delim::Pipe),
        _ => (inner, Delim::Comma),
    };
    if digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    let n: usize = digits.parse().ok()?;
    Some((n, delim))
}

/// Parse an optional leading key prefix (`unquoted` or `"quoted"`) that ends
/// right before a `[`. Returns the key and the byte index of `[`.
fn parse_optional_key_prefix(content: &str) -> Result<Option<(KeyTok, usize)>> {
    let bytes = content.as_bytes();
    if bytes.is_empty() {
        return Ok(None);
    }
    if bytes[0] == b'"' {
        // Quoted key prefix. `parse_quoted` returns the index of the closing
        // quote; the bracket segment starts one byte after it.
        let (text, end) = parse_quoted(content, 0)?;
        Ok(Some((KeyTok { text, quoted: true }, end + 1)))
    } else if bytes[0] == b'[' {
        // Root header (no key).
        Ok(None)
    } else {
        // Unquoted key prefix: read until '[' (identifier chars only).
        let mut i = 0;
        while i < bytes.len() && bytes[i] != b'[' {
            i += 1;
        }
        if i == 0 || i >= bytes.len() {
            return Ok(None);
        }
        let key = &content[..i];
        if !is_unquoted_key(key) {
            return Ok(None);
        }
        Ok(Some((
            KeyTok {
                text: key.to_string(),
                quoted: false,
            },
            i,
        )))
    }
}

/// Scan a `{...}` braces segment starting at byte index `open` (`content[open]
/// == '{'`). Returns the inner string and the byte index of the matching `}`.
fn scan_braces(content: &str, open: usize) -> Result<Option<(String, usize)>> {
    let bytes = content.as_bytes();
    let mut i = open + 1;
    let mut in_quotes = false;
    while i < bytes.len() {
        let c = bytes[i];
        if in_quotes {
            if c == b'\\' {
                i += 2;
                continue;
            }
            if c == b'"' {
                in_quotes = false;
            }
            i += 1;
            continue;
        }
        match c {
            b'"' => in_quotes = true,
            b'}' => {
                let inner = content[open + 1..i].to_string();
                return Ok(Some((inner, i)));
            }
            _ => {}
        }
        i += 1;
    }
    Ok(None)
}

/// Parse brace field names, split on the active delimiter, unescaping quoted.
fn parse_field_names(s: &str, delim: Delim) -> Result<Vec<FieldName>> {
    let parts = split_delimited(s, delim)?;
    let mut out = Vec::with_capacity(parts.len());
    for p in parts {
        let trimmed = p.trim();
        let text = if trimmed.starts_with('"') {
            let (t, end) = parse_quoted(trimmed, 0)?;
            if end + 1 != trimmed.len() {
                return Err(ToonError::new(
                    "Trailing characters after quoted field name",
                ));
            }
            t
        } else {
            trimmed.to_string()
        };
        out.push(FieldName { text });
    }
    Ok(out)
}

/// Parse a key from a key-value line. Returns `(key_text, was_quoted, rest)`
/// where `rest` is everything after the first unquoted colon (`:`).
fn parse_key(content: &str) -> Result<(String, bool, String)> {
    let bytes = content.as_bytes();
    if bytes.first() == Some(&b'"') {
        let (text, end) = parse_quoted(content, 0)?;
        // Expect ':' next (after optional nothing — spec wants colon directly).
        let mut k = end + 1;
        // Tolerate no spaces between quote and colon.
        if k >= bytes.len() || bytes[k] != b':' {
            return Err(ToonError::new("Missing colon after key"));
        }
        k += 1;
        return Ok((text, true, content[k..].to_string()));
    }
    // Unquoted: key up to first ':'.
    let mut i = 0;
    while i < bytes.len() && bytes[i] != b':' {
        i += 1;
    }
    if i >= bytes.len() {
        return Err(ToonError::new("Missing colon after key"));
    }
    let key = content[..i].trim_end().to_string();
    Ok((key, false, content[i + 1..].to_string()))
}

/// Is `content` a key-value line (has a usable colon, quoted-key-aware)?
fn is_key_value_line(content: &str) -> Result<bool> {
    let bytes = content.as_bytes();
    if bytes.is_empty() {
        return Ok(false);
    }
    if bytes[0] == b'"' {
        // Quoted key: find closing quote then a colon.
        match parse_quoted(content, 0) {
            Ok((_, end)) => Ok(end + 1 < bytes.len() && bytes[end + 1] == b':'),
            Err(_) => Ok(false),
        }
    } else {
        // Unquoted: presence of any ':' makes it a key-value line.
        Ok(content.contains(':'))
    }
}

/// Determine if a tabular-row-depth line should terminate rows (§9.3): it is a
/// key-value line (first unquoted colon precedes first unquoted delimiter, or
/// no delimiter at all).
fn is_row_terminator(content: &str, delim: Delim) -> Result<bool> {
    let dch = delim.ch();
    let bytes = content.as_bytes();
    let mut i = 0;
    let mut in_quotes = false;
    let mut first_colon: Option<usize> = None;
    let mut first_delim: Option<usize> = None;
    while i < bytes.len() {
        let c = bytes[i];
        if in_quotes {
            if c == b'\\' {
                i += 2;
                continue;
            }
            if c == b'"' {
                in_quotes = false;
            }
            i += 1;
            continue;
        }
        if c == b'"' {
            in_quotes = true;
            i += 1;
            continue;
        }
        let ch = content[i..].chars().next().unwrap();
        if ch == ':' && first_colon.is_none() {
            first_colon = Some(i);
        }
        if ch == dch && first_delim.is_none() {
            first_delim = Some(i);
        }
        i += ch.len_utf8();
    }
    Ok(match (first_colon, first_delim) {
        (None, _) => false,          // no colon → row
        (Some(_), None) => true,     // colon, no delim → key-value
        (Some(c), Some(d)) => c < d, // colon before delim → key-value
    })
}

/// Split `s` on `delim` honoring quoted substrings; preserve empty tokens.
fn split_delimited(s: &str, delim: Delim) -> Result<Vec<String>> {
    let dch = delim.ch();
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut in_quotes = false;
    let mut chars = s.char_indices().peekable();
    while let Some((_, c)) = chars.next() {
        if in_quotes {
            cur.push(c);
            if c == '\\' {
                if let Some((_, n)) = chars.next() {
                    cur.push(n);
                }
                continue;
            }
            if c == '"' {
                in_quotes = false;
            }
            continue;
        }
        if c == '"' {
            in_quotes = true;
            cur.push(c);
            continue;
        }
        if c == dch {
            out.push(std::mem::take(&mut cur));
            continue;
        }
        cur.push(c);
    }
    out.push(cur);
    Ok(out)
}

/// Parse a quoted string starting at byte index `start` (`content[start]=='"'`).
/// Returns `(unescaped, end_index_of_closing_quote)`. Rejects bad escapes (§7.1).
fn parse_quoted(content: &str, start: usize) -> Result<(String, usize)> {
    let bytes = content.as_bytes();
    debug_assert_eq!(bytes[start], b'"');
    let mut out = String::new();
    let mut i = start + 1;
    while i < bytes.len() {
        let c = bytes[i];
        if c == b'\\' {
            if i + 1 >= bytes.len() {
                return Err(ToonError::new("Unterminated string: trailing backslash"));
            }
            let e = bytes[i + 1];
            match e {
                b'\\' => out.push('\\'),
                b'"' => out.push('"'),
                b'n' => out.push('\n'),
                b'r' => out.push('\r'),
                b't' => out.push('\t'),
                other => {
                    return Err(ToonError::new(format!(
                        "Invalid escape sequence: \\{}",
                        other as char
                    )));
                }
            }
            i += 2;
            continue;
        }
        if c == b'"' {
            return Ok((out, i));
        }
        // Push the full UTF-8 char.
        let ch = content[i..].chars().next().unwrap();
        out.push(ch);
        i += ch.len_utf8();
    }
    Err(ToonError::new("Unterminated string: missing closing quote"))
}

/// Parse a primitive value token (§4 / B.4): quoted string, bool, null, number,
/// or unquoted string.
fn parse_primitive_token(token: &str) -> Result<Value> {
    let t = token.trim();
    if t.is_empty() {
        return Ok(Value::String(String::new()));
    }
    if t.starts_with('"') {
        let (text, end) = parse_quoted(t, 0)?;
        // No trailing characters allowed after the closing quote.
        if end + 1 != t.len() {
            return Err(ToonError::new("Trailing characters after quoted string"));
        }
        return Ok(Value::String(text));
    }
    match t {
        "true" => return Ok(Value::Bool(true)),
        "false" => return Ok(Value::Bool(false)),
        "null" => return Ok(Value::Null),
        _ => {}
    }
    if let Some(num) = parse_number_token(t) {
        return Ok(Value::Number(num));
    }
    Ok(Value::String(t.to_string()))
}

/// Parse a numeric token per §4 (accept decimal+exponent; reject forbidden
/// leading zeros). Returns `None` if not a valid number → caller treats as
/// string. The stored canonical text is derived from the parsed `f64`.
fn parse_number_token(t: &str) -> Option<Number> {
    if !is_decodable_number(t) {
        return None;
    }
    let v: f64 = t.parse().ok()?;
    // Normalize -0 to 0 at value layer; canonical text recomputed from value.
    let v = if v == 0.0 { 0.0 } else { v };
    Some(Number::from_parts(v, canonical_number(v)))
}

/// Grammar check for a decodable number (§4): optional sign, integer part with
/// no forbidden leading zeros, optional fraction, optional exponent.
fn is_decodable_number(t: &str) -> bool {
    let b = t.as_bytes();
    let mut i = 0;
    if i < b.len() && (b[i] == b'-' || b[i] == b'+') {
        // Spec examples use '-' and '+' only in exponent; leading '+' is not in
        // the reference forms, but '-' is. Accept leading '-' only.
        if b[i] == b'+' {
            return false;
        }
        i += 1;
    }
    let int_start = i;
    while i < b.len() && b[i].is_ascii_digit() {
        i += 1;
    }
    let int_len = i - int_start;
    if int_len == 0 {
        return false;
    }
    // Forbidden leading zero: integer part longer than 1 digit starting with 0,
    // UNLESS followed by '.' or 'e'/'E' (per §2 — but "05" stays a string).
    if int_len >= 2 && b[int_start] == b'0' {
        // "05", "0001" → not a number. (A single 0 then '.' is fine, handled
        // because int_len would be 1 in that case.)
        return false;
    }
    let mut has_frac_or_exp = false;
    if i < b.len() && b[i] == b'.' {
        i += 1;
        let frac_start = i;
        while i < b.len() && b[i].is_ascii_digit() {
            i += 1;
        }
        if i == frac_start {
            return false;
        }
        has_frac_or_exp = true;
    }
    if i < b.len() && (b[i] == b'e' || b[i] == b'E') {
        i += 1;
        if i < b.len() && (b[i] == b'+' || b[i] == b'-') {
            i += 1;
        }
        let exp_start = i;
        while i < b.len() && b[i].is_ascii_digit() {
            i += 1;
        }
        if i == exp_start {
            return false;
        }
        has_frac_or_exp = true;
    }
    let _ = has_frac_or_exp;
    i == b.len()
}

// ---------------------------------------------------------------------------
// Path expansion (§13.4 decoder, safe mode)
// ---------------------------------------------------------------------------

/// Expand dotted keys in an object into nested objects, with deep merge and
/// strict-mode conflict detection. `quoted_flags[i]` marks whether `fields[i]`
/// key was originally quoted (quoted keys are never expanded).
fn expand_object(value: Value, quoted_flags: &[bool], strict: bool) -> Result<Value> {
    let fields = match value {
        Value::Object(f) => f,
        other => return Ok(other),
    };
    let mut result: Vec<(String, Value)> = Vec::new();
    for (i, (key, val)) in fields.into_iter().enumerate() {
        let quoted = quoted_flags.get(i).copied().unwrap_or(false);
        let segments = expansion_segments(&key, quoted);
        match segments {
            None => {
                // Literal key. Recurse into nested objects for their own
                // expansion is already done at parse time; just merge as leaf.
                merge_into(&mut result, &[key], val, strict)?;
            }
            Some(segs) => {
                merge_into(&mut result, &segs, val, strict)?;
            }
        }
    }
    Ok(Value::Object(result))
}

/// Return the expansion segments for a key, or `None` if it stays literal.
fn expansion_segments(key: &str, quoted: bool) -> Option<Vec<String>> {
    if quoted {
        return None;
    }
    if !key.contains('.') {
        return None;
    }
    let segs: Vec<String> = key.split('.').map(|s| s.to_string()).collect();
    if segs.iter().all(|s| is_identifier_segment(s)) {
        Some(segs)
    } else {
        None
    }
}

/// Deep-merge a value at `path` into `target` (§13.4 deep merge + conflicts).
fn merge_into(
    target: &mut Vec<(String, Value)>,
    path: &[String],
    value: Value,
    strict: bool,
) -> Result<()> {
    let head = &path[0];
    if path.len() == 1 {
        // Leaf assignment.
        if let Some(slot) = target.iter_mut().find(|(k, _)| k == head) {
            match (&slot.1, &value) {
                (Value::Object(_), Value::Object(_)) => {
                    // Object+Object deep merge.
                    let existing = std::mem::replace(&mut slot.1, Value::Null);
                    slot.1 = deep_merge_values(existing, value, strict)?;
                }
                _ => {
                    if strict {
                        return Err(ToonError::new(format!(
                            "Expansion conflict at path '{head}'"
                        )));
                    }
                    slot.1 = value; // LWW
                }
            }
        } else {
            target.push((head.clone(), value));
        }
        return Ok(());
    }
    // Intermediate segment: ensure target[head] is an object, recurse.
    if let Some(slot) = target.iter_mut().find(|(k, _)| k == head) {
        match &mut slot.1 {
            Value::Object(inner) => {
                merge_into(inner, &path[1..], value, strict)?;
            }
            _ => {
                if strict {
                    return Err(ToonError::new(format!(
                        "Expansion conflict at path '{head}' (object vs non-object)"
                    )));
                }
                // LWW: replace with fresh object path.
                let mut inner = Vec::new();
                merge_into(&mut inner, &path[1..], value, strict)?;
                slot.1 = Value::Object(inner);
            }
        }
    } else {
        let mut inner = Vec::new();
        merge_into(&mut inner, &path[1..], value, strict)?;
        target.push((head.clone(), Value::Object(inner)));
    }
    Ok(())
}

/// Deep-merge two values (used when both are objects at a leaf collision).
fn deep_merge_values(a: Value, b: Value, strict: bool) -> Result<Value> {
    match (a, b) {
        (Value::Object(mut ao), Value::Object(bo)) => {
            for (k, v) in bo {
                merge_into(&mut ao, &[k], v, strict)?;
            }
            Ok(Value::Object(ao))
        }
        (_, b) => {
            if strict {
                Err(ToonError::new("Expansion conflict (object vs non-object)"))
            } else {
                Ok(b)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_simple_object() {
        let v = decode("id: 123\nname: Ada", true).unwrap();
        let s = encode(&v, &EncodeOptions::default());
        assert_eq!(s, "id: 123\nname: Ada");
    }

    #[test]
    fn canonical_numbers() {
        assert_eq!(canonical_number(1e20), "100000000000000000000");
        assert_eq!(canonical_number(0.000001), "0.000001");
        assert_eq!(canonical_number(-0.0), "0");
        assert_eq!(canonical_number(1.5), "1.5");
        assert_eq!(canonical_number(1000000.0), "1000000");
    }

    #[test]
    fn leading_zero_is_string() {
        let v = decode("value: 05", true).unwrap();
        match v {
            Value::Object(f) => match &f[0].1 {
                Value::String(s) => assert_eq!(s, "05"),
                _ => panic!("expected string"),
            },
            _ => panic!("expected object"),
        }
    }
}
