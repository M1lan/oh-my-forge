;;; toon.el --- Pure-Elisp TOON v3.0 codec  -*- lexical-binding: t; -*-

;; Author: erc-llm fabric (omf-jkh.8)
;; Keywords: data, serialization, toon
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:

;; A conformant, dependency-free codec for TOON (Token-Oriented Object
;; Notation) version 3.0, the line-oriented, indentation-based text format
;; that encodes the JSON data model.  This file runs on a vanilla
;; `emacs -q' using only built-in Elisp: no external packages, no C
;; modules, and -- critically -- no JSON library.  The codec never touches
;; json.el or `json-parse-string'; it implements TOON tokenization,
;; quoting, number canonicalization and strict-mode validation directly.
;;
;; This is the GNU/Emacs half of the erc-llm fabric.  It lets the Emacs
;; side speak the TOON wire format with the Rust daemon absent (the
;; decoupling guarantee).
;;
;; The spec is at https://github.com/toon-format/spec (v3.0).  Section
;; references (e.g. "Section 9.3") in the code point at that document.
;;
;;; Lisp Data Model
;;
;; The JSON data model maps to Elisp deterministically, preserving order:
;;
;;   object   -> alist `(("key" . VALUE) ...)' with STRING keys, in
;;               encounter order.
;;   array    -> a list, in order.
;;   null     -> the keyword `:null'
;;   true     -> `t'
;;   false    -> the keyword `:false'
;;   string   -> an Elisp string
;;   number   -> an Elisp integer (when integral) or float
;;
;; Empty object vs empty array.  An empty JSON array `[]' is the empty
;; list `nil'.  An empty JSON object `{}' is the distinct sentinel symbol
;; `toon-empty-object'.  These differ so that round-trips preserve the
;; object/array distinction, which `nil' alone cannot express.
;;
;;; API
;;
;;   (toon-encode VALUE &optional OPTS)  -> TOON string
;;   (toon-decode STRING &optional OPTS) -> Lisp value
;;
;; OPTS is a plist:
;;   :indent     integer spaces per level (default 2)
;;   :delimiter  one of `comma' (default), `tab', `pipe'
;;   :strict     non-nil to enforce strict-mode validation (default t)
;;
;; Decode errors are raised via `signal' under the `toon-error' condition.

;;; Code:

(require 'cl-lib)

(define-error 'toon-error "TOON codec error")

(defconst toon-empty-object 'toon-empty-object
  "Sentinel value representing an empty JSON object `{}'.
Distinct from the empty list `nil', which represents an empty array `[]'.")

;;;; Options helpers

(defun toon--opt (opts key default)
  "Return value of KEY in plist OPTS, or DEFAULT if KEY is absent."
  (if (plist-member opts key) (plist-get opts key) default))

(defun toon--delimiter-char (delim)
  "Map a delimiter designator DELIM to its character.
DELIM may be the symbols `comma', `tab', `pipe', or a literal
one-character string \",\", \"\\t\", or \"|\"."
  (pcase delim
    ('comma ?,) ('tab ?\t) ('pipe ?|)
    (?, ?,) (?\t ?\t) (?| ?|)
    ((pred stringp)
     (pcase delim
       ("," ?,) ("\t" ?\t) ("|" ?|)
       (_ (signal 'toon-error (list "invalid delimiter" delim)))))
    (_ (signal 'toon-error (list "invalid delimiter" delim)))))

;;;; ------------------------------------------------------------------
;;;; Number canonicalization (Section 2)
;;;; ------------------------------------------------------------------

(defun toon--canonical-number (n)
  "Return the canonical TOON decimal string for number N (Section 2).
No exponent notation, no leading zeros, no trailing fractional
zeros; integral floats become integers; -0 becomes 0."
  (cond
   ((integerp n) (number-to-string n))
   ((not (= n n)) "null")               ; NaN guard (caller normalizes)
   ((or (= n 1.0e+INF) (= n -1.0e+INF)) "null")
   ((= n 0.0) "0")                       ; handles -0.0 too
   ;; Integral-valued float: emit as integer.
   ((and (= n (ffloor n))
         (<= (abs n) 1.0e18))
    (number-to-string (truncate n)))
   (t (toon--float->decimal n))))

(defun toon--float->decimal (n)
  "Render float N as a canonical non-exponential decimal string."
  (let* ((s (number-to-string n)))
    (if (not (string-match-p "[eE]" s))
        (toon--strip-decimal-zeros s)
      (toon--expand-exponent s))))

(defun toon--strip-decimal-zeros (s)
  "Strip trailing fractional zeros from decimal string S.
\"1.5000\" -> \"1.5\"; \"2.0\" -> \"2\"."
  (if (string-match "\\." s)
      (let ((trimmed (replace-regexp-in-string "0+\\'" "" s)))
        (if (string-suffix-p "." trimmed)
            (substring trimmed 0 -1)
          trimmed))
    s))

(defun toon--expand-exponent (s)
  "Expand a float string S in exponent form to plain decimal.
For example \"1e-06\" -> \"0.000001\", \"1e+21\" -> a 1 followed
by 21 zeros.  Uses `calc'-free integer/string arithmetic."
  (string-match
   "\\`\\(-?\\)\\([0-9]+\\)\\(?:\\.\\([0-9]*\\)\\)?[eE]\\([+-]?[0-9]+\\)\\'" s)
  (let* ((sign (match-string 1 s))
         (int (match-string 2 s))
         (frac (or (match-string 3 s) ""))
         (exp (string-to-number (match-string 4 s)))
         (digits (concat int frac))
         ;; Position of the decimal point measured from the left of DIGITS.
         (point (+ (length int) exp)))
    (concat
     sign
     (cond
      ((<= point 0)
       (toon--strip-decimal-zeros
        (concat "0." (make-string (- point) ?0) digits)))
      ((>= point (length digits))
       (concat digits (make-string (- point (length digits)) ?0)))
      (t
       (toon--strip-decimal-zeros
        (concat (substring digits 0 point) "." (substring digits point))))))))

;;;; ------------------------------------------------------------------
;;;; Encoding (Sections 3, 5-12)
;;;; ------------------------------------------------------------------

(defconst toon--numeric-like-re
  "\\`-?\\(?:[0-9]+\\(?:\\.[0-9]+\\)?\\(?:[eE][+-]?[0-9]+\\)?\\|0[0-9]+\\)\\'"
  "Matches strings that look like numbers and must be quoted (Section 7.2).")

(defconst toon-object-tag 'toon-object
  "Head marker of a non-empty object: `(toon-object (\"k\" . v) ...)'.
Tagging objects disambiguates them from arrays-of-arrays, which would
otherwise share the same bare-alist shape (e.g. `((\"a\" \"b\"))').")

(defun toon--make-object (alist)
  "Build the codec object value from string-keyed ALIST.
Returns `toon-empty-object' when ALIST is empty, else a tagged object."
  (if alist (cons toon-object-tag alist) toon-empty-object))

(defun toon--object-p (v)
  "Return non-nil if V is the codec's representation of a non-empty object."
  (and (consp v) (eq (car v) toon-object-tag)))

(defun toon--object-alist (v)
  "Return the string-keyed alist of object value V (nil for empty object)."
  (cond ((eq v toon-empty-object) nil)
        ((toon--object-p v) (cdr v))
        (t (signal 'toon-error (list "not an object" v)))))

(defun toon--array-p (v)
  "Return non-nil if V is the codec's representation of a non-empty array."
  (and (consp v) (not (toon--object-p v))))

(defun toon--escape-string (s)
  "Escape S per Section 7.1 (the five escapes), returning the inner text."
  (let ((out (make-string 0 0)))
    (mapc
     (lambda (c)
       (setq out
             (concat out
                     (pcase c
                       (?\\ "\\\\") (?\" "\\\"")
                       (?\n "\\n") (?\r "\\r") (?\t "\\t")
                       (_ (char-to-string c))))))
     s)
    out))

(defun toon--quote-string (s)
  "Return S wrapped in double quotes with escapes applied (Section 7.1)."
  (concat "\"" (toon--escape-string s) "\""))

(defun toon--string-needs-quote-p (s delim-char)
  "Return non-nil if string value S must be quoted (Section 7.2).
DELIM-CHAR is the relevant delimiter character in scope."
  (or (string-empty-p s)
      (string-match-p "\\`[ \t]\\|[ \t]\\'" s)        ; leading/trailing ws
      (member s '("true" "false" "null"))
      (string-match-p toon--numeric-like-re s)
      (string-match-p "[:\"\\]" s)                    ; colon, quote, backslash
      (string-match-p "[][{}]" s)                     ; brackets, braces
      (string-match-p "[\n\r\t]" s)                   ; control chars
      (and delim-char (string-search (char-to-string delim-char) s))
      (string-prefix-p "-" s)))                       ; "-" or leading hyphen

(defun toon--encode-primitive (v delim-char)
  "Encode primitive V to a string, quoting per DELIM-CHAR scope (Section 7)."
  (cond
   ((eq v :null) "null")
   ((eq v t) "true")
   ((eq v :false) "false")
   ((numberp v) (toon--canonical-number v))
   ((stringp v)
    (if (toon--string-needs-quote-p v delim-char) (toon--quote-string v) v))
   (t (signal 'toon-error (list "not a primitive" v)))))

(defun toon--encode-key (k)
  "Encode object key / field name K (Section 7.3)."
  (if (string-match-p "\\`[A-Za-z_][A-Za-z0-9_.]*\\'" k)
      k
    (toon--quote-string k)))

(defun toon--primitive-p (v)
  "Return non-nil if V is a TOON primitive (string/number/bool/null)."
  (or (eq v :null) (eq v t) (eq v :false) (numberp v) (stringp v)))

(defun toon--tabular-p (arr)
  "Return non-nil and the ordered field list if ARR is tabular (Section 9.3).
All elements must be non-empty objects sharing the same key set with
primitive-only values.  Returns the first object's key order, or nil."
  (and (consp arr)
       (cl-every #'toon--object-p arr)
       (let* ((first-keys (mapcar #'car (toon--object-alist (car arr))))
              (key-set (sort (copy-sequence first-keys) #'string<)))
         (and first-keys
              (cl-every
               (lambda (obj)
                 (let ((al (toon--object-alist obj)))
                   (and (= (length al) (length first-keys))
                        (equal key-set (sort (mapcar #'car al) #'string<))
                        (cl-every (lambda (cell) (toon--primitive-p (cdr cell)))
                                  al))))
               arr)
              first-keys))))

(defun toon--obj-get (obj key)
  "Return value for KEY in object value OBJ (string keys)."
  (cdr (assoc key (toon--object-alist obj))))

(defun toon--indent (level indent-size)
  "Return the indentation string for LEVEL using INDENT-SIZE spaces."
  (make-string (* level indent-size) ?\s))

(cl-defstruct (toon--enc (:constructor toon--enc-make))
  "Encoder configuration."
  indent-size doc-delim-char)

(defun toon--encode-object-body (obj level enc lines)
  "Encode each field of OBJ at LEVEL with ENC, accumulating into LINES."
  (let ((ind (toon--indent level (toon--enc-indent-size enc))))
    (dolist (cell (toon--object-alist obj) lines)
      (setq lines (toon--encode-field (car cell) (cdr cell) ind level enc lines)))))

(defun toon--encode-field (key val ind level enc lines)
  "Encode one object field KEY: VAL at IND/LEVEL with ENC into LINES."
  (let ((ek (toon--encode-key key))
        (doc (toon--enc-doc-delim-char enc)))
    (cond
     ;; Empty object value -> "key:" on its own line.
     ((eq val toon-empty-object)
      (cons (concat ind ek ":") lines))
     ;; Non-empty object -> "key:" then nested body at +1.
     ((toon--object-p val)
      (toon--encode-object-body
       val (1+ level) enc (cons (concat ind ek ":") lines)))
     ;; Array value (including empty list).
     ((or (null val) (toon--array-p val))
      (toon--encode-array-field ek val ind level enc lines))
     ;; Primitive value.
     (t (cons (concat ind ek ": " (toon--encode-primitive val doc)) lines)))))

(defun toon--encode-array-field (ek arr ind level enc lines)
  "Encode an array field with header text EK at IND/LEVEL into LINES.
EK is the already-encoded key (or \"\" for a root array, handled elsewhere)."
  (let* ((adelim (toon--enc-doc-delim-char enc))
         (n (length arr))
         (suffix (toon--delim-suffix adelim))
         (fields (toon--tabular-p arr)))
    (cond
     ;; Empty array.
     ((null arr) (cons (concat ind ek "[0" suffix "]:") lines))
     ;; Tabular array of uniform objects.
     (fields
      (toon--encode-tabular ek arr fields ind level enc lines))
     ;; All-primitive -> inline.
     ((cl-every #'toon--primitive-p arr)
      (cons (concat ind ek "[" (number-to-string n) suffix "]: "
                    (toon--join-primitives arr adelim))
            lines))
     ;; Otherwise -> expanded list form.
     (t (toon--encode-list ek arr ind level enc lines)))))

(defun toon--delim-suffix (delim-char)
  "Return the header bracket delimiter suffix for DELIM-CHAR.
Comma is implicit (empty); tab and pipe are emitted literally."
  (pcase delim-char (?, "") (?\t "\t") (?| "|") (_ "")))

(defun toon--join-primitives (arr delim-char)
  "Join primitive list ARR with DELIM-CHAR, quoting per active delimiter."
  (mapconcat (lambda (v) (toon--encode-primitive v delim-char))
             arr (char-to-string delim-char)))

(defun toon--encode-tabular (ek arr fields ind level enc lines)
  "Encode tabular ARR with FIELDS under header EK at IND/LEVEL into LINES."
  (let* ((adelim (toon--enc-doc-delim-char enc))
         (suffix (toon--delim-suffix adelim))
         (dstr (char-to-string adelim))
         (header (concat ind ek "[" (number-to-string (length arr)) suffix "]{"
                         (mapconcat #'toon--encode-key fields dstr) "}:"))
         (rind (toon--indent (1+ level) (toon--enc-indent-size enc))))
    (setq lines (cons header lines))
    (dolist (obj arr lines)
      (setq lines
            (cons (concat rind
                          (mapconcat
                           (lambda (f)
                             (toon--encode-primitive (toon--obj-get obj f) adelim))
                           fields dstr))
                  lines)))))

(defun toon--encode-list (ek arr ind level enc lines)
  "Encode expanded list ARR under header EK at IND/LEVEL into LINES."
  (let* ((adelim (toon--enc-doc-delim-char enc))
         (suffix (toon--delim-suffix adelim))
         (header (concat ind ek "[" (number-to-string (length arr)) suffix "]:"))
         (item-level (1+ level))
         (iind (toon--indent item-level (toon--enc-indent-size enc))))
    (setq lines (cons header lines))
    (dolist (el arr lines)
      (setq lines (toon--encode-list-item el iind item-level enc lines)))))

(defun toon--encode-list-item (el iind ilevel enc lines)
  "Encode one list item EL at IIND/ILEVEL with ENC into LINES."
  (let ((doc (toon--enc-doc-delim-char enc)))
    (cond
     ;; Empty object list item -> bare hyphen.
     ((eq el toon-empty-object) (cons (concat iind "-") lines))
     ;; Empty array item -> "- [0...]:"
     ((null el)
      (cons (concat iind "- [0" (toon--delim-suffix doc) "]:") lines))
     ;; Primitive item -> "- <primitive>".
     ((toon--primitive-p el)
      (cons (concat iind "- " (toon--encode-primitive el doc)) lines))
     ;; Nested primitive/array-of-arrays or other arrays.
     ((toon--array-p el)
      (toon--encode-list-item-array el iind ilevel enc lines))
     ;; Object item.
     ((toon--object-p el)
      (toon--encode-list-item-object el iind ilevel enc lines))
     (t (signal 'toon-error (list "bad list item" el))))))

(defun toon--encode-list-item-array (arr iind ilevel enc lines)
  "Encode an array that is itself a list item, ARR, at IIND/ILEVEL into LINES.
A bare array element renders as `- [M...]: ...' for primitive inner arrays,
or `- [M...]:' followed by nested items at +1 for arrays of objects/mixed
elements (Section 9.4)."
  (let* ((doc (toon--enc-doc-delim-char enc))
         (suffix (toon--delim-suffix doc)))
    (if (cl-every #'toon--primitive-p arr)
        (cons (concat iind "- [" (number-to-string (length arr)) suffix "]: "
                      (toon--join-primitives arr doc))
              lines)
      ;; Array of objects/mixed as a list item: "- [N]:" then nested items +1.
      (let ((header (concat iind "- [" (number-to-string (length arr)) suffix "]:"))
            (nind (concat iind "  "))
            (nlevel (1+ ilevel)))
        (setq lines (cons header lines))
        (dolist (el arr lines)
          (setq lines (toon--encode-list-item el nind nlevel enc lines)))))))

(defun toon--encode-list-item-object (obj iind ilevel enc lines)
  "Encode object list item OBJ at IIND/ILEVEL with ENC into LINES (Section 10)."
  (let* ((alist (toon--object-alist obj))
         (first (car alist))
         (fkey (car first))
         (fval (cdr first))
         (field-level (1+ ilevel))
         (field-ind (toon--indent field-level (toon--enc-indent-size enc)))
         (first-tabular (and (or (null fval) (toon--array-p fval))
                             (toon--tabular-p fval))))
    (if first-tabular
        ;; Section 10: first field is a tabular array -> header on hyphen line,
        ;; rows at +2, remaining fields at +1.
        (let* ((doc (toon--enc-doc-delim-char enc))
               (suffix (toon--delim-suffix doc))
               (dstr (char-to-string doc))
               (header (concat iind "- " (toon--encode-key fkey)
                               "[" (number-to-string (length fval)) suffix "]{"
                               (mapconcat #'toon--encode-key first-tabular dstr) "}:"))
               (rind (toon--indent (+ ilevel 2) (toon--enc-indent-size enc))))
          (setq lines (cons header lines))
          (dolist (row fval)
            (setq lines
                  (cons (concat rind
                                (mapconcat
                                 (lambda (f)
                                   (toon--encode-primitive (toon--obj-get row f) doc))
                                 first-tabular dstr))
                        lines)))
          (dolist (cell (cdr alist) lines)
            (setq lines (toon--encode-field (car cell) (cdr cell)
                                            field-ind field-level enc lines))))
      ;; General case: render the first field at the field level, then splice
      ;; the hyphen marker into the head line (replacing its leading indent).
      (let* ((first-lines (nreverse (toon--encode-field
                                     fkey fval field-ind field-level enc nil)))
             (head (car first-lines))
             (hyphen-head (concat iind "- " (substring head (length field-ind)))))
        (setq lines (cons hyphen-head lines))
        (dolist (cont (cdr first-lines))
          (setq lines (cons cont lines)))
        (dolist (cell (cdr alist) lines)
          (setq lines (toon--encode-field (car cell) (cdr cell)
                                          field-ind field-level enc lines)))))))

;;;###autoload
(defun toon-encode (value &optional opts)
  "Encode VALUE (codec Lisp model) to a TOON string per OPTS.
OPTS is a plist accepting :indent, :delimiter, :strict (ignored on encode)."
  (let* ((indent-size (toon--opt opts :indent 2))
         (delim-char (toon--delimiter-char (toon--opt opts :delimiter 'comma)))
         (enc (toon--enc-make :indent-size indent-size :doc-delim-char delim-char))
         (suffix (toon--delim-suffix delim-char)))
    (cond
     ;; Empty object at root -> empty document.
     ((eq value toon-empty-object) "")
     ;; Empty array at root -> "[0...]:".
     ((null value) (concat "[0" suffix "]:"))
     ;; Root primitive.
     ((toon--primitive-p value) (toon--encode-primitive value delim-char))
     ;; Root array.
     ((toon--array-p value)
      (let ((lines '())
            (fields (toon--tabular-p value)))
        (cond
         (fields
          (setq lines (toon--encode-tabular "" value fields "" 0 enc lines)))
         ((cl-every #'toon--primitive-p value)
          (setq lines
                (cons (concat "[" (number-to-string (length value)) suffix "]: "
                              (toon--join-primitives value delim-char))
                      lines)))
         (t (setq lines (toon--encode-list "" value "" 0 enc lines))))
        (string-join (nreverse lines) "\n")))
     ;; Root object.
     ((toon--object-p value)
      (string-join (nreverse (toon--encode-object-body value 0 enc '())) "\n"))
     (t (signal 'toon-error (list "cannot encode" value))))))

;; Empty-value mapping at the root: `toon-empty-object' encodes to the empty
;; document ""; the empty list `nil' encodes to a root empty array "[0]:".
;; This mirrors the decode side, where "" decodes to `toon-empty-object' and
;; "[0]:" decodes to `nil'.

;;;; ------------------------------------------------------------------
;;;; Decoding (Sections 4-14)
;;;; ------------------------------------------------------------------

(cl-defstruct (toon--line (:constructor toon--line-make))
  "A scanned, non-blank input line."
  depth        ; indentation depth (spaces / indent-size)
  spaces       ; raw leading-space count
  text         ; content with leading indentation stripped
  number       ; 1-based source line number
  blank-before); non-nil if >=1 blank line immediately preceded this line

(cl-defstruct (toon--dec (:constructor toon--dec-make))
  "Decoder cursor over scanned lines."
  lines        ; vector of toon--line
  (pos 0)      ; current index
  indent       ; indent size
  strict)      ; strict-mode flag

(defun toon--derr (fmt &rest args)
  "Signal a `toon-error' with a formatted message."
  (signal 'toon-error (list (apply #'format fmt args))))

(defun toon--scan-lines (string indent strict)
  "Scan STRING into a vector of non-blank `toon--line' structs.
Records, per line, whether a blank line immediately preceded it (for the
blank-line-inside-array check, Section 14.4).  Validates indentation and
tab usage when STRICT (Section 14.3)."
  (let* ((raw (split-string string "\n"))
         (out '())
         (pending-blank nil)
         (lineno 0))
    (dolist (ln raw)
      (cl-incf lineno)
      (if (string-match-p "\\`[ \t]*\\'" ln)
          (setq pending-blank t)
        ;; Non-blank line.
        (let* ((wsend (or (string-match "[^ \t]" ln) (length ln)))
               (full-leading (substring ln 0 wsend))
               (nsp (or (string-match "[^ ]" ln) (length ln))))
          ;; Tab-in-indentation check (Section 14.3): any tab in the leading
          ;; whitespace span (spaces and tabs before the first content char).
          (when (and strict (string-search "\t" full-leading))
            (toon--derr "Tabs are not allowed in indentation"))
          (when (and strict (/= 0 (mod nsp indent)))
            (toon--derr "Indentation must be an exact multiple of %d spaces" indent))
          (push (toon--line-make
                 :depth (if (> indent 0) (/ nsp indent) 0)
                 :spaces nsp
                 :text (substring ln nsp)
                 :number lineno
                 :blank-before pending-blank)
                out)
          (setq pending-blank nil))))
    (vconcat (nreverse out))))

(defun toon--dec-peek (d)
  "Return the current line of decoder D, or nil at end."
  (when (< (toon--dec-pos d) (length (toon--dec-lines d)))
    (aref (toon--dec-lines d) (toon--dec-pos d))))

(defun toon--dec-next (d)
  "Return current line of D and advance the cursor."
  (prog1 (toon--dec-peek d) (cl-incf (toon--dec-pos d))))

;;;; Quoting-aware tokenization

(defun toon--unescape (s start end)
  "Unescape quoted-string body of S between START and END (Section 7.1).
Errors on invalid escapes or premature end."
  (let ((i start) (out '()))
    (while (< i end)
      (let ((c (aref s i)))
        (if (eq c ?\\)
            (progn
              (when (>= (1+ i) end)
                (toon--derr "Unterminated string: missing closing quote"))
              (let ((n (aref s (1+ i))))
                (push (pcase n
                        (?\\ ?\\) (?\" ?\") (?n ?\n) (?r ?\r) (?t ?\t)
                        (_ (toon--derr "Invalid escape sequence: \\%c" n)))
                      out)
                (setq i (+ i 2))))
          (push c out)
          (cl-incf i))))
    (apply #'string (nreverse out))))

(defun toon--read-quoted (s start)
  "Read a quoted token from S beginning at the opening quote at START.
Return a cons (VALUE . NEXT-INDEX) where VALUE is the unescaped string
and NEXT-INDEX is the position just past the closing quote.  Errors on
unterminated strings or invalid escapes."
  (let ((i (1+ start)) (len (length s)) (closed nil) (endq nil))
    (while (and (< i len) (not closed))
      (let ((c (aref s i)))
        (cond
         ((eq c ?\\) (setq i (+ i 2)))
         ((eq c ?\") (setq closed t endq i))
         (t (cl-incf i)))))
    (unless closed
      (toon--derr "Unterminated string: missing closing quote"))
    (cons (toon--unescape s (1+ start) endq) (1+ endq))))

(defun toon--split-delimited (s delim-char)
  "Split S on unquoted DELIM-CHAR (Section 11), trimming spaces around tokens.
Quoted segments are preserved verbatim (still containing their quotes).
Returns a list of raw token strings; empty tokens become \"\"."
  (let ((tokens '()) (cur (make-string 0 0))
        (i 0) (len (length s)) (in-q nil))
    (while (< i len)
      (let ((c (aref s i)))
        (cond
         (in-q
          (cond
           ((eq c ?\\) (setq cur (concat cur (substring s i (min len (+ i 2))))) (setq i (+ i 2)))
           ((eq c ?\") (setq cur (concat cur "\"")) (setq in-q nil) (cl-incf i))
           (t (setq cur (concat cur (char-to-string c))) (cl-incf i))))
         ((eq c ?\") (setq cur (concat cur "\"")) (setq in-q t) (cl-incf i))
         ((eq c delim-char)
          (push (string-trim cur) tokens)
          (setq cur (make-string 0 0)) (cl-incf i))
         (t (setq cur (concat cur (char-to-string c))) (cl-incf i)))))
    (push (string-trim cur) tokens)
    (nreverse tokens)))

(defun toon--parse-primitive-token (tok)
  "Parse a raw value token TOK into a Lisp primitive (Sections 4, B.4)."
  (cond
   ((string-empty-p tok) "")
   ((eq (aref tok 0) ?\")
    (let ((res (toon--read-quoted tok 0)))
      (unless (= (cdr res) (length tok))
        (toon--derr "Unexpected trailing content after quoted string"))
      (car res)))
   ((string= tok "true") t)
   ((string= tok "false") :false)
   ((string= tok "null") :null)
   ((toon--numeric-token-p tok) (toon--parse-number tok))
   (t tok)))

(defun toon--numeric-token-p (tok)
  "Return non-nil if TOK is a valid TOON number (Section 4, no leading zeros)."
  (and (string-match-p
        "\\`-?\\(?:0\\|[1-9][0-9]*\\)\\(?:\\.[0-9]+\\)?\\(?:[eE][+-]?[0-9]+\\)?\\'"
        tok)
       ;; Reject "0" followed by more integer digits handled by regex already.
       t))

(defun toon--parse-number (tok)
  "Parse numeric TOK to an integer (when integral) or float (Section 2/4)."
  (if (string-match-p "[.eE]" tok)
      (let ((f (string-to-number tok)))
        (cond
         ((= f 0.0) 0)                  ; -0, 0.0, 0e1 -> integer 0
         ((and (= f (ffloor f)) (<= (abs f) 1.0e18)) (truncate f))
         (t f)))
    (string-to-number tok)))            ; pure integer (bignum-safe)

;;;; Header parsing (Section 6)

(defun toon--parse-header (text)
  "Parse array-header TEXT into a plist, or nil if not a valid header.
Plist keys: :key (string or nil), :n, :delim (char), :fields (list or nil),
:inline (string after colon, or nil), :had-fields (bool).
Falls through to nil (key-value parsing) for malformed/extra-bracket lines."
  (cl-block toon--parse-header
    (let ((len (length text)) (i 0) (key nil))
      ;; Optional key: quoted or unquoted, ending right before '['.
      (cond
       ((and (> len 0) (eq (aref text 0) ?\"))
        (condition-case nil
            (let ((res (toon--read-quoted text 0)))
              (setq key (car res) i (cdr res)))
          (toon-error (cl-return-from toon--parse-header nil))))
       ((and (> len 0) (eq (aref text 0) ?\[))
        (setq key nil i 0))
       (t
        ;; Unquoted key up to first '['.
        (let ((b (string-search "[" text)))
          (unless b (cl-return-from toon--parse-header nil))
          (setq key (substring text 0 b) i b)
          (unless (string-match-p "\\`[A-Za-z_][A-Za-z0-9_.]*\\'" key)
            (cl-return-from toon--parse-header nil)))))
      ;; Expect '[' here.
      (unless (and (< i len) (eq (aref text i) ?\[))
        (cl-return-from toon--parse-header nil))
      (cl-incf i)
      ;; Length digits.
      (let ((ds i))
        (while (and (< i len) (>= (aref text i) ?0) (<= (aref text i) ?9))
          (cl-incf i))
        (when (= ds i) (cl-return-from toon--parse-header nil))
        (let ((n (string-to-number (substring text ds i)))
              (delim ?,))
          ;; Optional delimiter symbol.
          (when (and (< i len) (memq (aref text i) '(?\t ?|)))
            (setq delim (aref text i)) (cl-incf i))
          ;; Expect ']'.
          (unless (and (< i len) (eq (aref text i) ?\]))
            (cl-return-from toon--parse-header nil))
          (cl-incf i)
          ;; Optional whitespace, then '{' fields or ':'.
          (let ((fields nil) (had-fields nil))
            (when (and (< i len) (eq (aref text i) ?\{))
              (setq had-fields t)
              (let ((fe (string-search "}" text i)))
                (unless fe (cl-return-from toon--parse-header nil))
                (let ((fstr (substring text (1+ i) fe)))
                  (setq fields
                        (mapcar #'toon--parse-field-name
                                (toon--split-delimited fstr delim))))
                (setq i (1+ fe))))
            ;; Only whitespace allowed before colon (Section 6, 14.2).
            (let ((j i))
              (while (and (< j len) (eq (aref text j) ?\s)) (cl-incf j))
              (unless (and (< j len) (eq (aref text j) ?:))
                (cl-return-from toon--parse-header nil))
              (setq i (1+ j)))
            ;; Remaining text after colon: at most one leading space, then inline.
            (let ((inline (when (< i len)
                            (if (eq (aref text i) ?\s) (substring text (1+ i))
                              (substring text i)))))
              (list :key key :n n :delim delim :fields fields
                    :had-fields had-fields
                    :inline (if (and inline (string-empty-p inline)) nil inline)))))))))

(defun toon--parse-field-name (tok)
  "Parse a header field-name token TOK (quoted or unquoted) to a string."
  (if (and (> (length tok) 0) (eq (aref tok 0) ?\"))
      (car (toon--read-quoted tok 0))
    tok))

;;;; Key-value line parsing

(defun toon--parse-key (text)
  "Parse a leading key from TEXT, returning (KEY . REST-AFTER-COLON).
REST is the value text after \": \" or after \":\" (may be empty).
Errors when no colon follows the key (Section 14.2)."
  (if (and (> (length text) 0) (eq (aref text 0) ?\"))
      (let* ((res (toon--read-quoted text 0))
             (k (car res)) (i (cdr res)) (len (length text)))
        ;; Skip optional spaces, expect ':'.
        (while (and (< i len) (eq (aref text i) ?\s)) (cl-incf i))
        (unless (and (< i len) (eq (aref text i) ?:))
          (toon--derr "Missing colon after key"))
        (cl-incf i)
        (cons k (toon--value-after-colon text i)))
    (let ((ci (string-search ":" text)))
      (unless ci (toon--derr "Missing colon after key"))
      (cons (substring text 0 ci)
            (toon--value-after-colon text (1+ ci))))))

(defun toon--value-after-colon (text i)
  "Return value text in TEXT starting at I, stripping one leading space."
  (let ((len (length text)))
    (cond
     ((>= i len) "")
     ((eq (aref text i) ?\s) (substring text (1+ i)))
     (t (substring text i)))))

;;;; Recursive-descent structure decoding

(defun toon--decode-object (d depth)
  "Decode an object whose fields are at DEPTH from decoder D.
Consumes lines while depth >= DEPTH and returns the alist (string keys)."
  (let ((acc '()))
    (cl-block loop
      (while t
        (let ((line (toon--dec-peek d)))
          (when (or (null line) (< (toon--line-depth line) depth))
            (cl-return-from loop))
          (when (> (toon--line-depth line) depth)
            (toon--derr "Missing colon after key"))   ; orphan deeper line
          (toon--dec-next d)
          (let* ((text (toon--line-text line))
                 (hdr (toon--try-header text)))
            (if hdr
                (push (cons (or (plist-get hdr :key) "")
                            (toon--decode-array d hdr depth))
                      acc)
              ;; Key-value or nested object.
              (let* ((kv (toon--parse-key text))
                     (k (car kv)) (rest (cdr kv)))
                (if (string-empty-p rest)
                    ;; Nested object or empty object.
                    (let ((nxt (toon--dec-peek d)))
                      (if (and nxt (> (toon--line-depth nxt) depth))
                          (push (cons k (toon--decode-object d (1+ depth))) acc)
                        (push (cons k toon-empty-object) acc)))
                  (push (cons k (toon--parse-primitive-token rest)) acc))))))))
    (toon--make-object (nreverse acc))))

(defun toon--try-header (text)
  "Return parsed header plist for TEXT if it is a valid array header, else nil."
  (and (string-match-p "\\[" text)
       (toon--parse-header text)))

(defun toon--decode-array (d hdr depth)
  "Decode the array declared by header HDR; items live at DEPTH+1.
D is the decoder.  Returns the array value (a list, or `nil' if empty)."
  (let* ((n (plist-get hdr :n))
         (delim (plist-get hdr :delim))
         (fields (plist-get hdr :fields))
         (had-fields (plist-get hdr :had-fields))
         (inline (plist-get hdr :inline))
         (strict (toon--dec-strict d))
         (item-depth (1+ depth)))
    (cond
     ;; Inline primitive array (values on the header line).
     (inline
      (let ((vals (mapcar #'toon--parse-primitive-token
                          (toon--split-delimited inline delim))))
        (when (and strict (/= (length vals) n))
          (toon--derr "Expected %d values, but got %d" n (length vals)))
        vals))
     ;; Tabular array (has a fields segment).
     (had-fields
      (toon--decode-tabular d n delim fields item-depth strict))
     ;; Empty array declared with N=0 and no inline / no rows.
     ((and (= n 0)
           (let ((nxt (toon--dec-peek d)))
             (or (null nxt) (< (toon--line-depth nxt) item-depth))))
      nil)
     ;; Expanded list form.
     (t (toon--decode-list d n delim item-depth strict)))))

(defun toon--decode-tabular (d n delim fields depth strict)
  "Decode N tabular rows with FIELDS at DEPTH from D (Section 9.3)."
  (let ((rows '()) (count 0) (fc (length fields)))
    (cl-block loop
      (while t
        (let ((line (toon--dec-peek d)))
          (when (or (null line) (< (toon--line-depth line) depth))
            (cl-return-from loop))
          (when (> (toon--line-depth line) depth)
            (toon--derr "Unexpected indentation in tabular rows"))
          (let ((text (toon--line-text line)))
            ;; Row vs key-value disambiguation (Section 9.3).
            (unless (toon--row-line-p text delim)
              (cl-return-from loop))
            ;; Blank line inside the tabular block (Section 14.4).
            (when (and strict (> count 0) (toon--line-blank-before line))
              (toon--derr "Blank line inside array is not allowed"))
            (toon--dec-next d)
            (let ((vals (mapcar #'toon--parse-primitive-token
                                (toon--split-delimited text delim))))
              (when (and strict (/= (length vals) fc))
                (toon--derr "Expected %d values in row, but got %d" fc (length vals)))
              (push (toon--make-object (cl-mapcar #'cons fields vals)) rows)
              (cl-incf count))))))
    (when (and strict (/= count n))
      (toon--derr "Expected %d tabular rows, but got %d" n count))
    (nreverse rows)))

(defun toon--row-line-p (text delim)
  "Return non-nil if TEXT is a tabular row (not a key-value line) per Section 9.3."
  (let ((dpos (toon--first-unquoted text delim))
        (cpos (toon--first-unquoted text ?:)))
    (cond
     ((null cpos) t)                       ; no colon -> row
     ((null dpos) nil)                     ; colon but no delimiter -> kv
     ((< dpos cpos) t)                     ; delimiter first -> row
     (t nil))))                            ; colon first -> kv

(defun toon--first-unquoted (text ch)
  "Return index of first unquoted CH in TEXT, or nil."
  (let ((i 0) (len (length text)) (in-q nil) (found nil))
    (while (and (< i len) (not found))
      (let ((c (aref text i)))
        (cond
         (in-q
          (cond ((eq c ?\\) (cl-incf i 2))
                ((eq c ?\") (setq in-q nil) (cl-incf i))
                (t (cl-incf i))))
         ((eq c ?\") (setq in-q t) (cl-incf i))
         ((eq c ch) (setq found i))
         (t (cl-incf i)))))
    found))

(defun toon--decode-list (d n delim depth strict)
  "Decode an expanded list of N items at DEPTH from D (Sections 9.2/9.4/10)."
  (let ((items '()) (count 0))
    (cl-block loop
      (while t
        (let ((line (toon--dec-peek d)))
          (when (or (null line) (< (toon--line-depth line) depth))
            (cl-return-from loop))
          (when (> (toon--line-depth line) depth)
            (toon--derr "Unexpected indentation in list items"))
          (let ((text (toon--line-text line)))
            (unless (string-prefix-p "-" text)
              (cl-return-from loop))
            ;; Blank line inside the list block (Section 14.4).
            (when (and strict (> count 0) (toon--line-blank-before line))
              (toon--derr "Blank line inside array is not allowed"))
            (toon--dec-next d)
            (push (toon--decode-list-item d text delim depth) items)
            (cl-incf count)))))
    (when (and strict (/= count n))
      (toon--derr "Expected %d list array items, but got %d" n count))
    (nreverse items)))

(defun toon--decode-list-item (d text delim depth)
  "Decode a single list item from hyphen-line TEXT at DEPTH from D."
  (let ((body (cond ((string= text "-") nil)
                    ((string-prefix-p "- " text) (substring text 2))
                    (t (substring text 1)))))
    (cond
     ;; Bare hyphen -> empty object.
     ((null body) toon-empty-object)
     ;; Inline/nested array item: "- [M...]: ..." or "- [M...]:".
     ((toon--hyphen-array-p body)
      (toon--decode-hyphen-array d body delim depth))
     ;; Object item: first field on hyphen line (has an unquoted colon
     ;; or is a header with a key).
     ((toon--hyphen-object-p body)
      (toon--decode-hyphen-object d body delim depth))
     ;; Primitive item.
     (t (toon--parse-primitive-token body)))))

(defun toon--hyphen-array-p (body)
  "Return non-nil if list-item BODY is a bare inner array header \"[M...]:\"."
  (and (> (length body) 0) (eq (aref body 0) ?\[)
       (toon--parse-header body)))

(defun toon--hyphen-object-p (body)
  "Return non-nil if list-item BODY begins an object (has key + colon)."
  (or (toon--try-header body)            ; "- key[N]{...}:" or "- key[N]:"
      (toon--first-unquoted body ?:)))   ; "- key: value"

(defun toon--decode-hyphen-array (d body delim depth)
  "Decode a list item that is itself an array, from BODY at DEPTH (D)."
  (let* ((hdr (toon--parse-header body))
         ;; Items of this inner array sit two columns to the right of the
         ;; hyphen content, i.e. at depth+1 relative to the hyphen line.
         (inner-depth (1+ depth)))
    (toon--decode-array-with-header d hdr inner-depth delim)))

(defun toon--decode-array-with-header (d hdr item-depth _delim)
  "Decode array from HDR with explicit ITEM-DEPTH for nested contexts."
  (let* ((n (plist-get hdr :n))
         (hdelim (plist-get hdr :delim))
         (fields (plist-get hdr :fields))
         (had-fields (plist-get hdr :had-fields))
         (inline (plist-get hdr :inline))
         (strict (toon--dec-strict d)))
    (cond
     (inline
      (let ((vals (mapcar #'toon--parse-primitive-token
                          (toon--split-delimited inline hdelim))))
        (when (and strict (/= (length vals) n))
          (toon--derr "Expected %d values, but got %d" n (length vals)))
        vals))
     (had-fields
      (toon--decode-tabular d n hdelim fields item-depth strict))
     ((and (= n 0)
           (let ((nxt (toon--dec-peek d)))
             (or (null nxt) (< (toon--line-depth nxt) item-depth))))
      nil)
     (t (toon--decode-list d n hdelim item-depth strict)))))

(defun toon--decode-hyphen-object (d body delim depth)
  "Decode an object list item whose first field is on the hyphen line.
BODY is the post-hyphen text; DEPTH is the hyphen line's depth.  Other
fields sit at DEPTH+1; a first-field nested object sits at DEPTH+2."
  (let* ((acc '())
         (field-depth (1+ depth))
         (hdr (toon--try-header body)))
    (if hdr
        ;; First field is an array (possibly tabular at +2).
        (let* ((k (or (plist-get hdr :key) ""))
               (val (toon--decode-array-with-header
                     d hdr (+ depth 2) delim)))
          (push (cons k val) acc))
      ;; First field is a key: value or key: (nested object at +2).
      (let* ((kv (toon--parse-key body))
             (k (car kv)) (rest (cdr kv)))
        (if (string-empty-p rest)
            (let ((nxt (toon--dec-peek d)))
              (if (and nxt (>= (toon--line-depth nxt) (+ depth 2)))
                  (push (cons k (toon--decode-object d (+ depth 2))) acc)
                (push (cons k toon-empty-object) acc)))
          (push (cons k (toon--parse-primitive-token rest)) acc))))
    ;; Remaining sibling fields of this list-item object at DEPTH+1.
    (let ((more (toon--object-alist (toon--decode-object d field-depth))))
      (toon--make-object (nconc (nreverse acc) more)))))

;;;###autoload
(defun toon-decode (string &optional opts)
  "Decode TOON STRING to the codec Lisp model per OPTS.
OPTS is a plist accepting :indent, :strict.  Errors are signalled under
`toon-error' in strict mode."
  (let* ((indent (toon--opt opts :indent 2))
         (strict (toon--opt opts :strict t)))
    (let* ((lines (toon--scan-lines string indent strict))
           (d (toon--dec-make :lines lines :pos 0 :indent indent :strict strict)))
      (cond
       ;; Empty document -> empty object (Section 5).
       ((= (length lines) 0) toon-empty-object)
       (t (toon--decode-root d strict))))))

(defun toon--decode-root (d strict)
  "Decode the document root from decoder D (Section 5)."
  (let* ((first (toon--dec-peek d))
         (text (toon--line-text first))
         (hdr (toon--try-header text)))
    (cond
     ;; Root array header (no key, or key present makes it an object field).
     ((and hdr (null (plist-get hdr :key)))
      (toon--dec-next d)
      (toon--decode-array d hdr 0))
     ;; Single primitive root: exactly one line, not a header, not a kv line.
     ((and (= (length (toon--dec-lines d)) 1)
           (not hdr)
           (null (toon--first-unquoted text ?:)))
      (toon--parse-primitive-token text))
     ;; Two-or-more bare primitives at root -> invalid (strict, Section 5).
     ((and strict
           (> (length (toon--dec-lines d)) 1)
           (toon--all-bare-primitive-lines-p d))
      (toon--derr "Multiple primitives at root depth is not valid"))
     ;; Otherwise object.
     (t (toon--decode-object d 0)))))

(defun toon--all-bare-primitive-lines-p (d)
  "Return non-nil if every depth-0 line in D is a bare primitive (no colon/header)."
  (let ((lines (toon--dec-lines d)) (all t) (i 0))
    (while (and all (< i (length lines)))
      (let* ((ln (aref lines i)) (text (toon--line-text ln)))
        (when (or (/= (toon--line-depth ln) 0)
                  (toon--try-header text)
                  (toon--first-unquoted text ?:)
                  (string-prefix-p "-" text))
          (setq all nil)))
      (cl-incf i))
    all))

(provide 'toon)
;;; toon.el ends here
