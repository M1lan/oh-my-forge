# toon.el — Pure-Elisp TOON v3.0 codec

A conformant, dependency-free codec for **TOON** (Token-Oriented Object
Notation) version 3.0 — the line-oriented, indentation-based text format that
encodes the JSON data model. `toon.el` runs on a vanilla `emacs -q` using only
built-in Elisp: **no external packages, no C modules, and no JSON library**.

This is the GNU/Emacs half of the erc-llm fabric (beads `omf-jkh.8`). It lets
the Emacs side speak the TOON wire format with the Rust daemon absent — the
decoupling guarantee.

- Spec: `/Users/milan.santosi/mysrc/toon-spec/SPEC.md` (v3.0).
- The codec itself **never** touches `json.el` or `json-parse-string`. It
  implements TOON tokenization, quoting, number canonicalization and
  strict-mode validation directly.

## Files

- `toon.el` — the codec (`lexical-binding`, `(provide 'toon)`, byte-compiles
  with zero warnings).
- `toon-tests.el` — an ERT suite that reads the toon-spec conformance fixtures
  and runs them. The **test harness only** uses Emacs's built-in
  `json-parse-string` to read the fixtures and load each `expected`/`input`
  JSON value into the codec model. This is test-only oracle reading (not wire
  usage) and keeps the harness honest by reusing Emacs's own JSON as the
  oracle.

## API

```elisp
(toon-encode VALUE &optional OPTS)  ; -> TOON string
(toon-decode STRING &optional OPTS) ; -> Lisp value
```

`OPTS` is a plist:

| Key             | Default     | Meaning                                       |
|-----------------|-------------|-----------------------------------------------|
| `:indent`       | `2`         | Spaces per indentation level.                 |
| `:delimiter`    | `comma`     | Document delimiter: `comma`, `tab`, or `pipe`.|
| `:strict`       | `t`         | Enforce strict-mode validation (decode).      |
| `:key-folding`  | `off`       | Encoder dotted-path folding: `off` or `safe`. |
| `:flatten-depth`| `Infinity`  | Max segments to fold when `:key-folding safe`.|
| `:expand-paths` | `off`       | Decoder dotted-path expansion: `off` or `safe`.|

Decode errors are raised via `signal` under the `toon-error` condition
(`(define-error 'toon-error ...)`), so callers can wrap decoding in
`(condition-case err … (toon-error …))`.

## Lisp data model

The JSON data model maps to Elisp deterministically, **preserving order**:

| JSON          | Elisp representation                                  |
|---------------|------------------------------------------------------|
| object        | tagged alist `(toon-object ("k" . V) ...)`, **string** keys, encounter order |
| empty object  | the sentinel symbol `toon-empty-object`              |
| array         | a list, in order                                     |
| empty array   | the empty list `nil`                                 |
| `null`        | the keyword `:null`                                  |
| `true`        | `t`                                                  |
| `false`       | the keyword `:false`                                 |
| string        | an Elisp string                                      |
| number        | an Elisp integer (when integral) or float           |

### Why objects are tagged

A non-empty object is `(toon-object ("k" . V) ...)` — an alist with a leading
`toon-object` marker. The tag exists because a **bare** alist would be
ambiguous with an array of arrays: e.g. `(("a" "b"))` could be read either as
the object `{"a": ["b"]}` or as the array `[["a", "b"]]`. Tagging objects makes
the model unambiguous and round-trips exact. The convenience constructor
`toon--make-object` builds the right shape (and returns `toon-empty-object`
for an empty alist).

### Empty object vs empty array

Emacs's own JSON readers collapse both `{}` and `[]` to `nil`, which cannot
round-trip. This codec keeps them distinct:

- empty **object** `{}` → `toon-empty-object` (encodes to `key:` / empty
  document at root)
- empty **array** `[]` → `nil` (encodes to `key[0]:` / `[0]:` at root)

### Numbers

- Decode accepts decimal and exponent forms (`42`, `-3.14`, `1e-6`, `-1E+9`).
  Integral values (including from exponent forms, e.g. `-1E+03`) decode to an
  Elisp **integer**; non-integral values decode to a **float**. `-0`, `-0.0`,
  `0e1` normalize to integer `0`. Tokens with forbidden leading zeros (`05`,
  `-007`) decode as **strings** per §2/§4. Large integers use Emacs bignums.
- Encode emits canonical decimal form per §2: no exponent notation, no leading
  zeros, no trailing fractional zeros, integral floats as integers, `-0 → 0`.

## Running the tests

Byte-compile (must be zero warnings/errors):

```sh
emacs -Q --batch -f batch-byte-compile toon.el
```

Run the ERT suite headless:

```sh
emacs -Q --batch -L . -l toon.el -l toon-tests.el \
  -f ert-run-tests-batch-and-exit
```

The harness reads fixtures from
`/Users/milan.santosi/mysrc/toon-spec/tests/fixtures/{decode,encode}/*.json`
(path configurable via `toon-tests-fixtures-dir`). Each ERT test corresponds
to one fixture file and lists any sub-case failures in its failure message.

## Conformance status

All categories pass fully, including the optional Section 13.4 transforms:
encoder key folding (`:key-folding 'safe`, with `:flatten-depth`) and decoder
path expansion (`:expand-paths 'safe`, with strict-mode conflict handling per
Section 14.5). Both default off, so the wire format is unchanged unless a
caller opts in; quoted dotted keys are preserved literal on expansion, and
folding honors IdentifierSegment, depth, and sibling/root collision rules.

Sub-case tally (358/358 = 100%):

| Category                    | Pass / Total |
|-----------------------------|--------------|
| decode/primitives           | 25 / 25      |
| decode/objects              | 31 / 31      |
| decode/arrays-primitive     | 15 / 15      |
| decode/arrays-nested        | 22 / 22      |
| decode/arrays-tabular       |  7 / 7       |
| decode/delimiters           | 29 / 29      |
| decode/whitespace           |  6 / 6       |
| decode/root-form            |  1 / 1       |
| decode/numbers              | 22 / 22      |
| decode/blank-lines          | 13 / 13      |
| decode/validation-errors    | 10 / 10      |
| decode/indentation-errors   | 15 / 15      |
| decode/path-expansion       | 12 / 12      |
| encode/primitives           | 39 / 39      |
| encode/objects              | 26 / 26      |
| encode/arrays-primitive     | 12 / 12      |
| encode/arrays-nested        | 13 / 13      |
| encode/arrays-tabular       |  6 / 6       |
| encode/arrays-objects       | 16 / 16      |
| encode/delimiters           | 22 / 22      |
| encode/whitespace           |  3 / 3       |
| encode/key-folding          | 13 / 13      |

Regenerate this tally instead of trusting the snapshot:

```sh
emacs -Q --batch -L . -l toon.el -l toon-tests.el --eval \
  '(dolist (c (list "decode/primitives" "encode/primitives" ...)) ...)'
```

(The per-category counts above were produced by running each
`toon-tests--run-{decode,encode}-file` and counting `pass` results.)
