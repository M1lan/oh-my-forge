;;; populate-partyline.el --- seed #partyline with OMC's agent roster as dormant placeholders -*- lexical-binding: t; -*-

;; Loadable file (NOT inline lisp): `emacsclient -e '(load "…/populate-partyline.el")'`.
;; Injects OMC's agent roster into the live #partyline as *virtual participants*:
;; they appear in the channel (an honest JOIN the operator sees) but are NOT live
;; processes — inactive placeholders until @-pinged, at which point the erc-llm
;; bridge (or the future registry/agent-join, beads omf-jkh.16) materializes them.
;;
;; Idempotent: erc-llm-ircd-add-virtual no-ops if the nick is already present.
;; Safe: only runs if the embedded ircd is live; never starts a server, never JSON.

;;; Code:

(require 'erc-llm-ircd nil t)

(defconst omc-partyline-roster
  '(;; OMC dispatchable sub-agent archetypes ("my agents")
    "omc.planner" "omc.architect" "omc.executor" "omc.explorer"
    "omc.designer" "omc.writer" "omc.reviewer" "omc.verifier"
    "omc.debugger" "omc.scientist" "omc.tracer" "omc.critic"
    "omc.security" "omc.qa" "omc.gitmaster" "omc.doc-specialist"
    "omc.test-engineer" "omc.code-simplifier"
    ;; fabric peers not yet onboarded (placeholders for the roadmap)
    "omg" "omcp" "agy" "opencode" "crush")
  "OMC's agent roster seeded into #partyline as dormant virtual placeholders.
Live peers (omx, forge) are real socket clients and are intentionally omitted.")

(defun omc-populate-partyline ()
  "Add every nick in `omc-partyline-roster' to #partyline as a virtual placeholder.
Returns the count added.  No-op (with a message) if the ircd is not running."
  (if (not (and (fboundp 'erc-llm-ircd-running-p) (erc-llm-ircd-running-p)))
      (progn (message "omc-populate-partyline: ircd not running; nothing to seed") 0)
    (let ((n 0))
      (dolist (nick omc-partyline-roster)
        (erc-llm-ircd-add-virtual nick "#partyline")
        (setq n (1+ n)))
      (message "omc-populate-partyline: seeded %d placeholder agents into #partyline" n)
      n)))

;; Seed on load.
(omc-populate-partyline)

(provide 'populate-partyline)
;;; populate-partyline.el ends here
