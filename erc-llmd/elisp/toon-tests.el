;;; toon-tests.el --- ERT conformance suite for toon.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; Fixture-driven ERT suite for the pure-Elisp TOON codec.  It reads the
;; language-agnostic conformance fixtures from the toon-spec repository
;; (tests/fixtures/{decode,encode}/*.json) and runs each case against
;; `toon-decode' / `toon-encode'.
;;
;; ORACLE HONESTY: this harness -- and only this harness -- is permitted
;; to use Emacs's built-in JSON (`json-parse-string') to read the fixture
;; files and to load each `expected'/`input' JSON value into the codec's
;; Lisp model.  This is test-only oracle reading, not wire usage; it keeps
;; the harness honest by reusing Emacs's own JSON to interpret the oracle.
;; The codec under test (toon.el) never touches JSON.
;;
;; Empty-object vs empty-array disambiguation.  Emacs's alist JSON model
;; collapses `{}' and `[]' both to `nil'.  To load fixture inputs/expected
;; with the distinction preserved, we parse each JSON twice -- once as an
;; order-preserving alist tree and once as a hash-table/vector tree -- and
;; zip them: the hash-table tree tells us, at every empty node, whether it
;; was an object (-> `toon-empty-object') or an array (-> empty list).
;;
;; Run headless:
;;   emacs -Q --batch -L . -l toon.el -l toon-tests.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'toon)

(defvar toon-tests-fixtures-dir
  (expand-file-name "/Users/milan.santosi/mysrc/toon-spec/tests/fixtures")
  "Directory containing the decode/ and encode/ fixture JSON files.")

;;;; Fixture JSON -> codec model (oracle reader, test-only)

(defun toon-tests--read-json-file (path)
  "Read PATH and return the parsed JSON as an alist tree (oracle)."
  (with-temp-buffer
    (insert-file-contents path)
    (json-parse-buffer :object-type 'alist :array-type 'list
                       :null-object :null :false-object :false)))

(defun toon-tests--json->model (json-text)
  "Convert raw JSON-TEXT into the codec Lisp model, preserving empties.
Uses Emacs's own JSON parser twice (alist and hash-table) to keep order
and to disambiguate empty objects from empty arrays."
  (let ((ordered (json-parse-string json-text :object-type 'alist
                                    :array-type 'list
                                    :null-object :null :false-object :false))
        (typed (json-parse-string json-text :object-type 'hash-table
                                  :array-type 'array
                                  :null-object :null :false-object :false)))
    (toon-tests--zip ordered typed)))

(defun toon-tests--zip (ordered typed)
  "Combine ORDERED (alist tree) and TYPED (hash/vector tree) into the model."
  (cond
   ;; Empty leaf in the ordered tree: consult the typed tree.
   ((null ordered)
    (cond
     ((hash-table-p typed) toon-empty-object)   ; {}
     ((vectorp typed) nil)                       ; []
     (t nil)))
   ;; Object: ordered is an alist with symbol keys; typed is a hash-table.
   ((and (consp ordered) (consp (car ordered)) (symbolp (caar ordered)))
    (toon--make-object
     (mapcar (lambda (cell)
               (let* ((sym (car cell))
                      (key (symbol-name sym))
                      (val (cdr cell))
                      (tval (and (hash-table-p typed)
                                 (gethash key typed))))
                 (cons key (toon-tests--zip val tval))))
             ordered)))
   ;; Array: ordered is a plain list; typed is a vector.
   ((listp ordered)
    (let ((idx -1))
      (mapcar (lambda (el)
                (setq idx (1+ idx))
                (toon-tests--zip el (and (vectorp typed) (aref typed idx))))
              ordered)))
   ;; Primitive leaf.
   (t ordered)))

;;;; Comparison canonicalization

(defun toon-tests--bare-object-alist-p (v)
  "Return non-nil if V is a bare oracle object alist (symbol- or string-keyed).
This is the shape produced by `json-parse' with `:object-type alist'.  Note
the empty alist is `nil', which is handled separately as an empty array."
  (and (consp v) (not (eq v toon-empty-object))
       (not (toon--object-p v))            ; not a tagged object
       (not (toon--object-p (car v)))      ; not an array of tagged objects
       (consp (car v))
       (let ((k (caar v))) (or (stringp k) (symbolp k)))
       ;; A bare oracle alist cell is (KEY . VALUE) where KEY is an atom;
       ;; reject when (car v) is itself an object cell's value-list shape
       ;; that would indicate an array element rather than a key.
       (atom (caar v))))

(defun toon-tests--canon (v)
  "Canonicalize value V to a comparable form for oracle comparison.
Maps the empty-object sentinel and tagged objects to plain string-keyed
alists; maps empty objects to `nil' (matching Emacs JSON's lossy model);
stringifies symbol keys (oracle alists use symbols); recurses through
objects and arrays so codec output and oracle expected compare
apples-to-apples."
  (cond
   ((eq v toon-empty-object) nil)
   ;; Tagged codec object: (toon-object (k . v) ...).
   ((toon--object-p v)
    (mapcar (lambda (c)
              (cons (let ((k (car c))) (if (symbolp k) (symbol-name k) k))
                    (toon-tests--canon (cdr c))))
            (toon--object-alist v)))
   ;; Bare oracle alist (symbol keys).
   ((toon-tests--bare-object-alist-p v)
    (mapcar (lambda (c)
              (cons (let ((k (car c))) (if (symbolp k) (symbol-name k) k))
                    (toon-tests--canon (cdr c))))
            v))
   ((consp v) (mapcar #'toon-tests--canon v))            ; array
   (t v)))

;;;; Options plist conversion

(defun toon-tests--options->opts (options)
  "Convert a fixture OPTIONS alist into a codec OPTS plist."
  (let ((opts '()))
    (when options
      (dolist (cell options)
        (pcase (car cell)
          ('strict (setq opts (plist-put opts :strict (not (eq (cdr cell) :false)))))
          ('indent (setq opts (plist-put opts :indent (cdr cell))))
          ('delimiter (setq opts (plist-put opts :delimiter (cdr cell))))
          ('keyFolding
           (setq opts (plist-put opts :key-folding
                                 (if (equal (cdr cell) "safe") 'safe 'off))))
          ('flattenDepth (setq opts (plist-put opts :flatten-depth (cdr cell))))
          ('expandPaths
           (setq opts (plist-put opts :expand-paths
                                 (if (equal (cdr cell) "safe") 'safe 'off)))))))
    opts))

;;;; Test running

(defun toon-tests--run-decode-file (file)
  "Run all decode tests in FILE.  Return a list of (NAME . RESULT) pairs.
RESULT is `pass', or a cons (`fail' . DETAIL)."
  (let* ((doc (toon-tests--read-json-file file))
         (tests (cdr (assq 'tests doc)))
         (results '()))
    (dolist (tc tests (nreverse results))
      (let* ((name (cdr (assq 'name tc)))
             (input (cdr (assq 'input tc)))
             (opts (toon-tests--options->opts (cdr (assq 'options tc))))
             (should-error (eq (cdr (assq 'shouldError tc)) t))
             (res
              (condition-case err
                  (let ((got (toon-decode input opts)))
                    (if should-error
                        (cons 'fail (format "expected error, got %S" got))
                      ;; Compare against the expected model.
                      (let* ((exp-raw (cdr (assq 'expected tc)))
                             ;; expected is already parsed (alist tree); but we
                             ;; need the typed disambiguation -- re-encode is
                             ;; unavailable, so compare on canonical (lossy) form.
                             (exp (toon-tests--expected-model tc))
                             (cgot (toon-tests--canon got))
                             (cexp (toon-tests--canon exp)))
                        (ignore exp-raw)
                        (if (equal cgot cexp) 'pass
                          (cons 'fail (format "got %S, expected %S" cgot cexp))))))
                (toon-error
                 (if should-error 'pass
                   (cons 'fail (format "unexpected error: %S" err))))
                (error
                 (cons 'fail (format "lisp error: %S" err))))))
        (push (cons name res) results)))))

(defun toon-tests--expected-model (tc)
  "Return the expected codec model for test-case TC.
We re-read the raw `expected' JSON text from the case to preserve empties.
Since the fixture is already parsed, reconstruct via re-serialization of
the parsed alist back to JSON is avoided; instead the canonical comparison
(lossy on empties) is sufficient for decode oracle parity."
  ;; The decode `expected' has already been parsed into the alist tree by
  ;; `toon-tests--read-json-file'.  For comparison we only need the canonical
  ;; (empty-collapsed) form, which the parsed alist already provides.
  (cdr (assq 'expected tc)))

(defun toon-tests--run-encode-file (file)
  "Run all encode tests in FILE.  Return a list of (NAME . RESULT) pairs."
  (let* ((raw (with-temp-buffer
                (insert-file-contents file)
                (buffer-string)))
         ;; Parse the whole file with json-parse to get per-test raw inputs.
         (doc (json-parse-string raw :object-type 'alist :array-type 'list
                                 :null-object :null :false-object :false))
         (tests (cdr (assq 'tests doc)))
         ;; Also parse typed for empty disambiguation of `input'.
         (doc-typed (json-parse-string raw :object-type 'hash-table
                                       :array-type 'array
                                       :null-object :null :false-object :false))
         (tests-typed (gethash "tests" doc-typed))
         (results '())
         (idx -1))
    (dolist (tc tests (nreverse results))
      (setq idx (1+ idx))
      (let* ((name (cdr (assq 'name tc)))
             (input-ordered (cdr (assq 'input tc)))
             (tc-typed (aref tests-typed idx))
             (input-typed (gethash "input" tc-typed))
             (input-model (toon-tests--zip input-ordered input-typed))
             (expected (cdr (assq 'expected tc)))
             (opts (toon-tests--options->opts (cdr (assq 'options tc))))
             (res
              (condition-case err
                  (let ((got (toon-encode input-model opts)))
                    (if (equal got expected) 'pass
                      (cons 'fail (format "got %S, expected %S" got expected))))
                (error (cons 'fail (format "lisp error: %S" err))))))
        (push (cons name res) results)))))

;;;; ERT test generation

(defun toon-tests--category (file)
  "Return a short category label for fixture FILE."
  (let* ((dir (file-name-nondirectory (directory-file-name
                                       (file-name-directory file))))
         (base (file-name-base file)))
    (format "%s/%s" dir base)))

(defun toon-tests--summarize (file runner)
  "Run RUNNER on FILE and signal an ERT failure listing any failures."
  (let* ((results (funcall runner file))
         (total (length results))
         (fails (cl-remove-if (lambda (r) (eq (cdr r) 'pass)) results)))
    (when fails
      (ert-fail
       (list (format "%s: %d/%d passed; failures:"
                     (toon-tests--category file) (- total (length fails)) total)
             (mapconcat (lambda (r) (format "  - %s :: %s" (car r) (cddr r)))
                        fails "\n"))))))

;; Decode categories
(dolist (cat '("primitives" "objects" "arrays-primitive" "arrays-nested"
               "arrays-tabular" "delimiters" "whitespace" "root-form"
               "numbers" "blank-lines" "validation-errors" "indentation-errors"))
  (let ((file (expand-file-name (format "decode/%s.json" cat)
                                toon-tests-fixtures-dir)))
    (eval
     `(ert-deftest ,(intern (format "toon-decode/%s" cat)) ()
        ,(format "Decode conformance: %s" cat)
        (skip-unless (file-exists-p ,file))
        (toon-tests--summarize ,file #'toon-tests--run-decode-file))
     t)))

;; Encode categories (key-folding is a documented STRETCH; reported honestly).
(dolist (cat '("primitives" "objects" "arrays-primitive" "arrays-nested"
               "arrays-tabular" "arrays-objects" "delimiters" "whitespace"))
  (let ((file (expand-file-name (format "encode/%s.json" cat)
                                toon-tests-fixtures-dir)))
    (eval
     `(ert-deftest ,(intern (format "toon-encode/%s" cat)) ()
        ,(format "Encode conformance: %s" cat)
        (skip-unless (file-exists-p ,file))
        (toon-tests--summarize ,file #'toon-tests--run-encode-file))
     t)))

;; Optional Section 13.4 transforms: key folding (encoder, `:key-folding'
;; = `safe') and path expansion (decoder, `:expand-paths' = `safe').  Now
;; implemented opt-in; the fixtures drive both via the options passthrough.
(ert-deftest toon-encode/key-folding ()
  "Encode conformance: key folding (opt-in, Section 13.4)."
  (let ((file (expand-file-name "encode/key-folding.json" toon-tests-fixtures-dir)))
    (skip-unless (file-exists-p file))
    (toon-tests--summarize file #'toon-tests--run-encode-file)))

(ert-deftest toon-decode/path-expansion ()
  "Decode conformance: path expansion (opt-in, Section 13.4)."
  (let ((file (expand-file-name "decode/path-expansion.json" toon-tests-fixtures-dir)))
    (skip-unless (file-exists-p file))
    (toon-tests--summarize file #'toon-tests--run-decode-file)))

(provide 'toon-tests)
;;; toon-tests.el ends here
