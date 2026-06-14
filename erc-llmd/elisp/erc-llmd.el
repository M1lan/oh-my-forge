;;; erc-llmd.el --- Point ERC at an EXTERNAL erc-llmd daemon socket -*- lexical-binding: t; -*-

;; Author: erc-llmd
;; Keywords: comm, processes
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; This is the CLIENT-SIDE companion to the standalone `erc-llmd' Rust daemon.
;; Unlike `llm-erc.el' (which starts the Emacs-resident pseudo-ircd), this file
;; assumes `erc-llmd' is ALREADY RUNNING and owns the socket.  It does NOT start
;; any embedded server -- it only dials an existing AF_UNIX socket and JOINs the
;; partyline, exactly the way `erc-llm--connect' does.
;;
;; Because erc-llmd speaks the same wire protocol, ERC connects unchanged, and
;; the partyline survives Emacs death (the daemon keeps running).
;;
;; Load it (never inline `--eval'):
;;
;;     emacs -q -l /path/to/erc-llmd/elisp/erc-llmd.el
;;
;; then `M-x erc-llmd-connect'.  Override the socket via the prefix arg, the
;; `erc-llmd-socket-path' custom, or the `ERC_LLM_SOCK' environment variable.
;;
;; SECURITY: AF_UNIX only; no TCP, no JSON, no shell-out.

;;; Code:

(require 'erc)

(defgroup erc-llmd nil
  "ERC client for the standalone erc-llmd partyline daemon."
  :group 'comm
  :prefix "erc-llmd-")

(defcustom erc-llmd-socket-path
  (or (getenv "ERC_LLM_SOCK")
      (expand-file-name "ircd.sock" "~/.local/state/erc-llm/"))
  "Filesystem path of the AF_UNIX socket the erc-llmd daemon listens on.
Defaults to the ERC_LLM_SOCK environment variable when set, else the
canonical `~/.local/state/erc-llm/ircd.sock'."
  :type 'file
  :group 'erc-llmd)

(defcustom erc-llmd-server-name "erc-llm.local"
  "Server name erc-llmd reports.  Used only to recognise our connection."
  :type 'string
  :group 'erc-llmd)

(defcustom erc-llmd-default-channel "#partyline"
  "Channel to JOIN automatically once connected."
  :type 'string
  :group 'erc-llmd)

(defcustom erc-llmd-nick (or (user-login-name) "operator")
  "Nick the operator uses in the partyline."
  :type 'string
  :group 'erc-llmd)

(defvar erc-llmd--connect-target nil
  "Absolute socket path the connect function should dial (set at launch).")

(defun erc-llmd--connect (name buffer _host _service &rest _params)
  "ERC connect function: dial the erc-llmd Unix socket instead of TCP.
Signature matches `erc-server-connect-function' / `open-network-stream':
NAME and BUFFER are used; HOST/SERVICE are ignored (we always dial the
local socket `erc-llmd--connect-target')."
  (make-network-process
   :name name
   :buffer buffer
   :family 'local
   :service (or erc-llmd--connect-target
                (expand-file-name erc-llmd-socket-path))
   :coding 'utf-8
   :nowait nil))

(defun erc-llmd--after-connect (server _nick)
  "JOIN the partyline once connected to the erc-llmd SERVER."
  (when (string-match-p (regexp-quote erc-llmd-server-name) (or server ""))
    (erc-cmd-JOIN erc-llmd-default-channel)
    (remove-hook 'erc-after-connect #'erc-llmd--after-connect)))

;;;###autoload
(defun erc-llmd-connect (&optional socket)
  "Connect ERC to an EXISTING external erc-llmd daemon and JOIN the partyline.
This does NOT start any server -- erc-llmd must already own the socket.

SOCKET defaults to `erc-llmd-socket-path'.  Interactively, a prefix
argument prompts for the socket path."
  (interactive
   (list (when current-prefix-arg
           (read-file-name "erc-llmd socket: " "~/.local/state/erc-llm/"
                           nil t "ircd.sock"))))
  (let ((path (expand-file-name (or socket erc-llmd-socket-path))))
    (unless (file-exists-p path)
      (user-error "erc-llmd: socket not found: %s (is the daemon running?)" path))
    (setq erc-llmd--connect-target path)
    (add-hook 'erc-after-connect #'erc-llmd--after-connect)
    (let ((erc-server-connect-function #'erc-llmd--connect))
      (erc :server erc-llmd-server-name
           :port 6667
           :nick erc-llmd-nick
           :full-name "erc-llmd"))
    (message "erc-llmd: connecting to %s as %s" path erc-llmd-nick)))

(provide 'erc-llmd)
;;; erc-llmd.el ends here
