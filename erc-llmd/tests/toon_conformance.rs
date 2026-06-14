//! TOON v3.0 conformance harness.
//!
//! Walks the language-agnostic fixture oracle at
//! `~/mysrc/toon-spec/tests/fixtures/{decode,encode}/*.json` (schema:
//! `tests/fixtures.schema.json`) and runs every case against the codec in
//! `erc_llmd::toon`.
//!
//! This is the ONLY place the crate touches `serde_json`, and it is a
//! `[dev-dependencies]` entry — used purely to parse the fixture files and
//! convert their `expected`/`input` JSON values into the codec's `Value`. The
//! shipped library and binary stay dependency-free.
//!
//! Each fixture file is `{ "category": "decode"|"encode", "tests": [...] }`.
//! For decode tests: `input` is a TOON string, `expected` is a JSON value (or
//! `shouldError: true`). For encode tests: `input` is a JSON value, `expected`
//! is a TOON string. `options` carries indent/strict/delimiter/keyFolding/
//! flattenDepth/expandPaths.
//!
//! The harness prints a per-file PASS/FAIL table and asserts that the core
//! categories are fully green. Stretch fixtures (key-folding, path-expansion)
//! are reported but do not fail the build by default.

use std::path::{Path, PathBuf};

use erc_llmd::toon::{
    decode_with, encode, DecodeOptions, Delimiter, EncodeOptions, ExpandPaths, KeyFolding, Number,
    Value,
};
use serde_json::Value as J;

fn fixtures_root() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    Path::new(&home).join("mysrc/toon-spec/tests/fixtures")
}

// --- JSON <-> Value conversion -------------------------------------------

/// Convert a JSON value to the codec `Value`. Object key order is preserved
/// because the harness enables serde_json's `preserve_order` feature.
fn json_to_value(j: &J) -> Value {
    match j {
        J::Null => Value::Null,
        J::Bool(b) => Value::Bool(*b),
        J::Number(n) => Value::Number(Number::from_f64(n.as_f64().unwrap())),
        J::String(s) => Value::String(s.clone()),
        J::Array(a) => Value::Array(a.iter().map(json_to_value).collect()),
        J::Object(o) => Value::Object(
            o.iter()
                .map(|(k, v)| (k.clone(), json_to_value(v)))
                .collect(),
        ),
    }
}

/// Compare a decoded `Value` against an expected JSON value. Object comparison
/// is order-sensitive (the harness preserves JSON key order), enforcing TOON's
/// §2 key-order guarantee. Numbers are compared by `f64` value.
fn value_eq_json(v: &Value, j: &J) -> bool {
    match (v, j) {
        (Value::Null, J::Null) => true,
        (Value::Bool(a), J::Bool(b)) => a == b,
        (Value::Number(a), J::Number(b)) => {
            let bf = b.as_f64().unwrap();
            a.as_f64() == bf || (a.as_f64() - bf).abs() < 1e-12 * bf.abs().max(1.0)
        }
        (Value::String(a), J::String(b)) => a == b,
        (Value::Array(a), J::Array(b)) => {
            a.len() == b.len() && a.iter().zip(b).all(|(x, y)| value_eq_json(x, y))
        }
        (Value::Object(a), J::Object(b)) => {
            if a.len() != b.len() {
                return false;
            }
            // Order-sensitive zip comparison (both preserve insertion order).
            a.iter()
                .zip(b.iter())
                .all(|((ak, av), (bk, bv))| ak == bk && value_eq_json(av, bv))
        }
        _ => false,
    }
}

// --- Options parsing ------------------------------------------------------

fn decode_options(opts: Option<&J>) -> DecodeOptions {
    let mut d = DecodeOptions::default();
    if let Some(J::Object(o)) = opts {
        if let Some(J::Bool(s)) = o.get("strict") {
            d.strict = *s;
        }
        if let Some(J::Number(n)) = o.get("indent") {
            d.indent = n.as_u64().unwrap_or(2) as usize;
        }
        if let Some(J::String(e)) = o.get("expandPaths") {
            d.expand_paths = if e == "safe" {
                ExpandPaths::Safe
            } else {
                ExpandPaths::Off
            };
        }
    }
    d
}

fn encode_options(opts: Option<&J>) -> EncodeOptions {
    let mut e = EncodeOptions::default();
    if let Some(J::Object(o)) = opts {
        if let Some(J::Number(n)) = o.get("indent") {
            e.indent = n.as_u64().unwrap_or(2) as usize;
        }
        if let Some(J::String(d)) = o.get("delimiter") {
            e.delimiter = match d.as_str() {
                "\t" => Delimiter::Tab,
                "|" => Delimiter::Pipe,
                _ => Delimiter::Comma,
            };
        }
        if let Some(J::String(k)) = o.get("keyFolding") {
            e.key_folding = if k == "safe" {
                KeyFolding::Safe
            } else {
                KeyFolding::Off
            };
        }
        if let Some(J::Number(n)) = o.get("flattenDepth") {
            e.flatten_depth = Some(n.as_u64().unwrap_or(0) as usize);
        }
    }
    e
}

// --- Harness --------------------------------------------------------------

struct FileResult {
    name: String,
    passed: usize,
    failed: usize,
    failures: Vec<String>,
}

fn run_file(path: &Path) -> FileResult {
    let raw = std::fs::read_to_string(path).expect("read fixture");
    let doc: J = serde_json::from_str(&raw).expect("parse fixture json");
    let category = doc["category"].as_str().unwrap().to_string();
    let tests = doc["tests"].as_array().unwrap();

    let mut passed = 0;
    let mut failed = 0;
    let mut failures = Vec::new();

    for test in tests.iter() {
        let name = test["name"].as_str().unwrap_or("<unnamed>").to_string();
        let should_error = test
            .get("shouldError")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        let opts = test.get("options");

        let ok = if category == "decode" {
            let input = test["input"].as_str().unwrap_or("");
            let d = decode_options(opts);
            let res = decode_with(input, &d);
            if should_error {
                res.is_err()
            } else {
                match res {
                    Ok(v) => value_eq_json(&v, &test["expected"]),
                    Err(_) => false,
                }
            }
        } else {
            // encode: input is a JSON value (key order preserved).
            let input_val = json_to_value(&test["input"]);
            let e = encode_options(opts);
            let produced = encode(&input_val, &e);
            let expected = test["expected"].as_str().unwrap_or("");
            produced == expected
        };

        if ok {
            passed += 1;
        } else {
            failed += 1;
            failures.push(name);
        }
    }

    FileResult {
        name: format!(
            "{}/{}",
            path.parent()
                .unwrap()
                .file_name()
                .unwrap()
                .to_string_lossy(),
            path.file_name().unwrap().to_string_lossy()
        ),
        passed,
        failed,
        failures,
    }
}

fn collect_fixtures(dir: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Ok(entries) = std::fs::read_dir(dir) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().map(|x| x == "json").unwrap_or(false) {
                out.push(p);
            }
        }
    }
    out.sort();
    out
}

#[test]
fn toon_conformance() {
    let root = fixtures_root();
    if !root.exists() {
        eprintln!(
            "SKIP: fixture oracle not found at {} — conformance not run",
            root.display()
        );
        return;
    }

    // Stretch fixtures: reported but not gated.
    let stretch = ["encode/key-folding.json", "decode/path-expansion.json"];

    let mut results = Vec::new();
    for sub in ["decode", "encode"] {
        for path in collect_fixtures(&root.join(sub)) {
            results.push(run_file(&path));
        }
    }

    println!("\n=== TOON conformance per-file results ===");
    println!("{:<34} {:>6} {:>6}", "fixture", "pass", "fail");
    println!("{}", "-".repeat(48));
    let mut core_failures = 0usize;
    let mut total_pass = 0usize;
    let mut total_fail = 0usize;
    for r in &results {
        let is_stretch = stretch.iter().any(|s| r.name.ends_with(s));
        let tag = if is_stretch { " (stretch)" } else { "" };
        println!("{:<34} {:>6} {:>6}{}", r.name, r.passed, r.failed, tag);
        for f in &r.failures {
            println!("    FAIL: {f}");
        }
        total_pass += r.passed;
        total_fail += r.failed;
        if !is_stretch {
            core_failures += r.failed;
        }
    }
    println!("{}", "-".repeat(48));
    println!(
        "TOTAL: {} passed, {} failed ({} core failures)",
        total_pass, total_fail, core_failures
    );

    assert_eq!(
        core_failures, 0,
        "core conformance fixtures must all pass; {core_failures} core failures"
    );
}
