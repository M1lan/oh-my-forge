;;; erc-llmd-prefer.el --- Prefer an external erc-llmd daemon, else embed -*- lexical-binding: t; -*-

;; Author: erc-llmd
;; Keywords: comm, processes
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Single entry point that DOES THE RIGHT THING depending on who owns the
;; partyline socket:
;;
;;   * IF an external `erc-llmd' daemon is ALREADY SERVING the socket, connect
;;     ERC to it as a pure CLIENT and do NOT start any embedded server.  The
;;     partyline then survives Emacs death (the daemon keeps running).
;;
;;   * ELSE fall back to the embedded P0 pseudo-ircd via `llm-erc' from
;;     `llm-erc.el' (Emacs becomes the server).
;;
;; This lets a config opt into "use the daemon when it's up, otherwise spin up
;; the in-Emacs ircd" with a single command, without ever inlining `--eval',
;; without JSON, and reusing the existing `erc-llmd--connect' connect-function
;; idiom (we delegate to `erc-llmd-connect' from the sibling `erc-llmd.el').
;;
;; OPT-IN (add to your init; this file does NOT edit your config):
;;
;;     ;; load order: the two client shims, then this preferer
;;     (add-to-list 'load-path "/path/to/oh-my-forge/erc-llmd/elisp")
;;     (require 'erc-llmd)         ; external-daemon client
;;     (require 'erc-llmd-prefer)  ; this file
;;     ;; optional: bind a key, or just M-x erc-llmd-prefer-llm-erc
;;     (global-set-key (kbd "C-c L") #'erc-llmd-prefer-llm-erc)
;;
;; The embedded fallback additionally needs `llm-erc' on `load-path' (the live
;; `~/.emacs.d/lisp/ai/erc-llm/' tree).  If `llm-erc' is unavailable, the
;; command still works whenever the daemon is up, and only errors (clearly)
;; when it would have to fall back but cannot.
;;
;; SECURITY: AF_UNIX only; no TCP, no JSON, no shell-out.
;;
;;; Detection heuristic (and its limits) -- read this before trusting it
;;
;; "An external erc-llmd daemon owns the socket" is decided by
;; `erc-llmd-prefer-external-daemon-p', which is true when BOTH hold:
;;
;;   (a) the socket path is a LIVE LISTENER -- not merely an existing file.
;;       We test this the only portable way from Emacs Lisp: open a
;;       non-blocking AF_UNIX *client* connection to the path and see whether
;;       the connect succeeds.  A live listener accepts (we immediately close
;;       the probe); a stale leftover socket file refuses with ECONNREFUSED; a
;;       missing path errors.  Either failure => not a live listener.
;;
;;   (b) it is NOT *this* Emacs's embedded ircd.  If `erc-llm-ircd-running-p'
;;       is fboundp and returns non-nil, this very Emacs is the server, so we
;;       must NOT treat it as "external" (that would make us connect to
;;       ourselves and skip our own startup bookkeeping).  When the embedded
;;       ircd feature is not even loaded, a live listener can only be foreign,
;;       so (b) is vacuously satisfied.
;;
;; LIMITATIONS / honesty:
;;
;;   * It identifies "a live listener that is not THIS Emacs's embedded ircd."
;;     It does NOT cryptographically prove the peer is specifically the
;;     `erc-llmd' Rust binary.  ANY process listening on that AF_UNIX path
;;     (another Emacs running `llm-erc', a hand-rolled `nc -lU', a different
;;     daemon) reads as "external."  For our purpose -- "should I start my own
;;     embedded ircd, or just connect?" -- that is the correct question: if
;;     something already serves the socket, starting a second server would
;;     fail/clobber, so connecting is right regardless of which compatible
;;     server it is.  It DOES assume the listener speaks the same wire
;;     protocol; a foreign non-erc-llmd listener on that exact path would be
;;     mis-detected (out of scope -- the path is ours by convention).
;;
;;   * TOCTOU race: detection and the subsequent connect are two separate
;;     syscalls.  A daemon can die (or start) in the gap, so a "prefer
;;     external" decision can still hit a refused connect, and a "fall back to
;;     embedded" decision can race a daemon that comes up a millisecond later
;;     (then `erc-llm-ircd-start' would find the path in use).  We do not, and
;;     from a single Emacs process CANNOT, hold a lock across both steps.  The
;;     window is small but real; the fallback paths surface the error rather
;;     than hiding it.
;;
;;   * The probe is a real (if instantaneous) connection attempt.  On a live
;;     daemon it briefly appears and disappears as a client; harmless, but not
;;     literally zero-observable.

;;; Code:

(require 'erc-llmd)        ; erc-llmd-socket-path, erc-llmd-connect, the connect idiom

;; `llm-erc' / `erc-llm-ircd' come from the live ~/.emacs.d tree and may or may
;; not be on `load-path' at compile/run time; reference them softly so this
;; file byte-compiles clean under `emacs -Q' without them present.
(declare-function llm-erc "llm-erc" ())
(declare-function erc-llm-ircd-running-p "erc-llm-ircd" ())

(defgroup erc-llmd-prefer nil
  "Prefer an external erc-llmd daemon, falling back to the embedded ircd."
  :group 'erc-llmd
  :prefix "erc-llmd-prefer-")

(defcustom erc-llmd-prefer-socket-path
  (expand-file-name "ircd.sock" "~/.local/state/erc-llm/")
  "AF_UNIX socket path to probe for an external erc-llmd daemon.
Defaults to the canonical `~/.local/state/erc-llm/ircd.sock'.

This intentionally MIRRORS `erc-llmd-socket-path' (from `erc-llmd.el')
but is kept as its own custom so the detection target and the connect
target can be reasoned about independently.  When you change one you
almost always want to change the other."
  :type 'file
  :group 'erc-llmd-prefer)

(defcustom erc-llmd-prefer-probe-timeout 0.5
  "Seconds to wait for the non-blocking listener probe to settle.
The probe opens a non-blocking AF_UNIX client connection and waits up to
this long for it to reach an `open' (live listener) or `failed' (stale
socket) state.  Kept small: a local listener accepts essentially
instantly."
  :type 'number
  :group 'erc-llmd-prefer)

(defun erc-llmd-prefer--live-listener-p (path)
  "Return non-nil if PATH is a LIVE AF_UNIX listener (not a stale socket file).
Opens a non-blocking client connection to PATH and inspects the result:
a live listener yields process status `open'; a stale/refused socket
yields `failed'; a missing path or any other error yields nil.  The probe
connection is always deleted before returning -- we never linger as a
client."
  (let ((path (expand-file-name path))
        (probe nil))
    (and
     (file-exists-p path)
     (unwind-protect
         (condition-case _err
             (progn
               (setq probe
                     (make-network-process
                      :name "erc-llmd-prefer-probe"
                      :family 'local
                      :service path
                      :coding 'binary
                      :noquery t
                      :nowait t))
               ;; Drive the non-blocking connect to a terminal state.
               (let ((deadline (+ (float-time) erc-llmd-prefer-probe-timeout)))
                 (while (and (eq (process-status probe) 'connect)
                             (< (float-time) deadline))
                   (accept-process-output probe 0.05)))
               (eq (process-status probe) 'open))
           ;; ECONNREFUSED / ENOENT etc. all mean "no live listener here".
           (file-error nil)
           (error nil))
       (when (process-live-p probe)
         (delete-process probe))))))

(defun erc-llmd-prefer--embedded-ircd-is-ours-p ()
  "Return non-nil if the embedded pseudo-ircd is running inside THIS Emacs.
Soft reference: if `erc-llm-ircd-running-p' is not loaded, the embedded
ircd cannot be ours, so return nil."
  (and (fboundp 'erc-llm-ircd-running-p)
       (erc-llm-ircd-running-p)))

;;;###autoload
(defun erc-llmd-prefer-external-daemon-p (&optional path)
  "Return non-nil if an EXTERNAL erc-llmd daemon owns the socket.
PATH defaults to `erc-llmd-prefer-socket-path'.

True iff the socket is a live listener (see
`erc-llmd-prefer--live-listener-p') AND that listener is not this Emacs's
own embedded ircd (see `erc-llmd-prefer--embedded-ircd-is-ours-p').  See
this file's commentary for the full heuristic and its limitations."
  (let ((path (or path erc-llmd-prefer-socket-path)))
    (and (erc-llmd-prefer--live-listener-p path)
         (not (erc-llmd-prefer--embedded-ircd-is-ours-p)))))

;;;###autoload
(defun erc-llmd-prefer-llm-erc (&optional socket)
  "Connect to an external erc-llmd daemon if present, else embed via `llm-erc'.
SOCKET overrides `erc-llmd-prefer-socket-path'.  Interactively, a prefix
argument prompts for the socket path.

Decision (see `erc-llmd-prefer-external-daemon-p'):

  * external daemon serving the socket -> `erc-llmd-connect' (pure client,
    no embedded server started; the partyline outlives Emacs);

  * otherwise -> `llm-erc' (start/reuse the embedded P0 pseudo-ircd).

Note the inherent TOCTOU race: the daemon can appear or vanish between
this check and the connect; in that case the delegated command surfaces
the error rather than silently doing the wrong thing."
  (interactive
   (list (when current-prefix-arg
           (read-file-name "erc-llmd socket: " "~/.local/state/erc-llm/"
                           nil nil "ircd.sock"))))
  (let ((path (expand-file-name (or socket erc-llmd-prefer-socket-path))))
    (if (erc-llmd-prefer-external-daemon-p path)
        (progn
          (message "erc-llmd-prefer: external daemon on %s -> connecting as client" path)
          ;; `erc-llmd-connect' dials the existing socket via the
          ;; `erc-llmd--connect' connect-function and JOINs the partyline.
          (erc-llmd-connect path))
      (if (fboundp 'llm-erc)
          (progn
            (message "erc-llmd-prefer: no external daemon -> embedded llm-erc on %s" path)
            (llm-erc))
        (user-error
         (concat "erc-llmd-prefer: no external daemon on %s and `llm-erc' is "
                 "not available to fall back to (load ~/.emacs.d/lisp/ai/erc-llm/)")
         path)))))

(provide 'erc-llmd-prefer)
;;; erc-llmd-prefer.el ends here
