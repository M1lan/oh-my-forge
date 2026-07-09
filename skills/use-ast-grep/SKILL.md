---
name: use-ast-grep
description: "GLOBAL mandatory preference: MUST USE ast-grep (AST-aware structural code search) when exploring codebases or performing semantic searches. Prefer ast-grep over rg/grep for any code-structure query — function signatures, call sites, trait/interface implementations, type usages, import patterns. rg remains for plain-text/regex searches over non-code or log files. This is a strict, non-negotiable user preference."
---

# Use `ast-grep` for Code Exploration and Semantic Search — Always

`ast-grep` (`/opt/homebrew/bin/ast-grep`, version 0.43+) performs AST-aware
structural pattern matching across a codebase. It understands code syntax, not
just text, so it finds real code constructs rather than string matches.

## When to use `ast-grep` (MANDATORY)

- Finding function/method definitions or call sites
- Locating trait implementations, interface implementors
- Discovering how a type or variable is used across a codebase
- Exploring an unfamiliar codebase's structure (entry points, error handling patterns, API surface)
- Any "semantic" query: "where is X called?", "which functions return Y?", "where is Z constructed?"
- Code refactoring search: finding all sites that match a structural pattern before rewriting

## When `rg` is still appropriate

- Searching log files, plain text, comments, or documentation
- Searching for a literal string across arbitrary file types
- Fast filename search (use `fd` for that)
- Config files (YAML, TOML, JSON) — no AST grammars for those

## Command form

```bash
ast-grep run --pattern '<PATTERN>' --lang <LANG> [PATH]
ast-grep run --pattern '<PATTERN>' --lang <LANG> --json [PATH]   # machine-readable
ast-grep run --pattern '<PATTERN>' --lang <LANG> --files-with-matches [PATH]
```

## Meta-variables (the pattern language)

| Syntax | Matches |
|--------|---------|
| `$VAR` | Any single AST node (expression, identifier, type, ...) |
| `$$$VAR` | Zero or more nodes (vararg / spread) |
| `$_` | Any single node, unnamed (wildcard) |
| `$$$` | Any sequence of nodes, unnamed |

### Strictness (default: `smart`)

`--strictness <level>` controls how strictly the pattern matches:

| Level | Behaviour |
|-------|-----------|
| `smart` | Ignore trivial whitespace/comment nodes (DEFAULT) |
| `ast` | Match AST nodes only, ignoring comments |
| `relaxed` | Match AST except comments, ignore text |
| `signature` | Match structure only — text values ignored |

## Supported languages (key subset)

`rust`, `python`, `js`/`javascript`, `ts`/`typescript`, `tsx`, `go`,
`java`, `kotlin`, `c`, `cpp`, `cs`, `ruby`, `php`, `swift`, `scala`,
`bash`/`sh`, `json`, `yaml`, `html`, `css`, `lua`, `elixir`, `haskell`

Full list: <https://ast-grep.github.io/reference/languages.html>

## Quick-reference patterns

### Rust

```bash
# All public function definitions
ast-grep run --pattern 'pub fn $NAME($$$) $$$' --lang rust

# All unwrap() call sites
ast-grep run --pattern '$EXPR.unwrap()' --lang rust

# All match expressions
ast-grep run --pattern 'match $EXPR { $$$ }' --lang rust

# Impl blocks for a specific trait
ast-grep run --pattern 'impl $TRAIT for $TYPE { $$$ }' --lang rust

# All use of ?-operator on Result
ast-grep run --pattern '$EXPR?' --lang rust

# Struct definitions
ast-grep run --pattern 'struct $NAME { $$$ }' --lang rust

# Functions returning Result
ast-grep run --pattern 'fn $NAME($$$) -> Result<$$$> { $$$ }' --lang rust
```

### Python

```bash
# All class definitions
ast-grep run --pattern 'class $NAME($$$): $$$' --lang python

# All function definitions
ast-grep run --pattern 'def $NAME($$$): $$$' --lang python

# All raise statements
ast-grep run --pattern 'raise $EXPR' --lang python

# All decorator usages
ast-grep run --pattern '@$DECORATOR' --lang python

# All comprehensions
ast-grep run --pattern '[$EXPR for $VAR in $ITER]' --lang python
```

### TypeScript / JavaScript

```bash
# All arrow functions
ast-grep run --pattern '($$$) => $$$' --lang ts

# All async functions
ast-grep run --pattern 'async function $NAME($$$) { $$$ }' --lang ts

# All React hooks
ast-grep run --pattern 'use$HOOK($$$)' --lang tsx

# All import statements from a module
ast-grep run --pattern 'import $$$  from "$MOD"' --lang ts

# All await expressions
ast-grep run --pattern 'await $EXPR' --lang ts
```

### Go

```bash
# All error checks
ast-grep run --pattern 'if $ERR != nil { $$$ }' --lang go

# All goroutines
ast-grep run --pattern 'go $FUNC($$$)' --lang go

# All struct definitions
ast-grep run --pattern 'type $NAME struct { $$$ }' --lang go

# All defer statements
ast-grep run --pattern 'defer $EXPR' --lang go
```

## Codebase exploration workflow

When dropped into an unfamiliar codebase:

```bash
# 1. Find entry points (main functions)
ast-grep run --pattern 'fn main() { $$$ }' --lang rust --files-with-matches .
ast-grep run --pattern 'func main() { $$$ }' --lang go --files-with-matches .

# 2. Map error handling patterns
ast-grep run --pattern '$EXPR.unwrap()' --lang rust -l .
ast-grep run --pattern '$EXPR.expect($MSG)' --lang rust -l .

# 3. Find all public API surface
ast-grep run --pattern 'pub fn $NAME($$$) $$$' --lang rust .

# 4. Find trait implementations
ast-grep run --pattern 'impl $TRAIT for $TYPE { $$$ }' --lang rust .

# 5. Locate test functions
ast-grep run --pattern '#[test] fn $NAME() { $$$ }' --lang rust .
```

## Output flags

| Flag | Use |
|------|-----|
| `--files-with-matches` | List only files containing matches (like `rg -l`) |
| `--json` | Structured JSON output (range + text) for piping |
| `-A N` / `-B N` / `-C N` | Context lines around match |
| `--interactive` | Confirm rewrites interactively (with `--rewrite`) |
| `--update-all` | Apply all rewrites non-interactively |

## Rewrite (structural find-and-replace)

```bash
# Rename a function
ast-grep run --pattern 'old_name($$$ARGS)' --rewrite 'new_name($$$ARGS)' --lang rust --update-all

# Swap argument order
ast-grep run --pattern 'foo($A, $B)' --rewrite 'foo($B, $A)' --lang rust --interactive
```

## Precedence over `rg` / `sem_search`

| Query type | Tool |
|------------|------|
| AST structure (functions, types, calls, patterns) | `ast-grep` FIRST |
| Intent / doc / comment / conceptual | `sem_search` |
| Exact literal string anywhere | `rg` |
| File names | `fd` |

NEVER use `rg` to search for code structure when `ast-grep` can express the query.
This is a strict, non-negotiable user preference.
