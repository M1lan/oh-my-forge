# forge-history.zsh -- C-f reverse-by-date wordwise search of `: ` forge prompts
#
# The user-visible feature:
#   Hit Ctrl-F at the zsh prompt.  An fzf picker opens, listing every Forge
#   prompt the user has ever sent that started with `: ` (a colon followed by
#   a space and free-form text -- often multi-paragraph), newest first, with
#   a date column.  Typing a query does WORDWISE AND-SUBSTRING matching:
#   each space-separated token must appear as a substring in the row; rows
#   that don't contain every token are hidden.  No fuzzy letter scatter.
#   The list ordering does NOT change as you type -- only non-matching rows
#   disappear -- so the more you type, the smaller and more focused the
#   list gets, in stable chronological order.  Empty query shows everything
#   newest-first.  Pressing Enter inserts the selected prompt into the
#   command line, prefixed with `: ` so it can be re-sent or edited.
#
# Why this exists / why it isn't just shell history:
#   atuin's history_filter = ["^:"] keeps these prompts OUT of the regular
#   shell history -- by design, so they don't pollute up-arrow / Ctrl-R.
#   But that also means we can't reach them from atuin.  So we collect
#   `: ` prompts from every source that DOES retain them:
#
# Data sources (oldest -> newest, deduped, last-occurrence wins):
#
#   1. ~/forge/.forge_history       (the canonical source: forge's own
#                                    append-only log, one prompt per line.
#                                    Forge strips the leading `: ` before
#                                    writing, so we re-add it on display.
#                                    No timestamps; we synthesise them from
#                                    file order + mtime so date-sort still
#                                    makes sense.)
#
#   2. $FORGE_HISTFILE              (this plugin's TSV log:
#                                    `timestamp \t cwd \t command`,
#                                    appended by the forge-accept-line
#                                    wrapper below; gives real timestamps
#                                    + cwd for entries typed since the
#                                    wrapper was installed.)
#
#   3. $HISTFILE                    (zsh extended_history.  forge-accept-line
#                                    upstream calls `print -s` on the buffer,
#                                    so `: ` prompts DO land here unless
#                                    hist_ignore_space ate them.  We extract
#                                    `: TS:0;: ...` lines.)
#
#   4. ~/.local/share/atuin/history.db  (atuin's sqlite DB.  Most `: ...`
#                                    lines are blocked by history_filter,
#                                    but a few sneak through and atuin syncs
#                                    across machines, so this can pick up
#                                    prompts typed elsewhere.)
#
# Dependencies: fzf (required), sqlite3 (optional, for atuin source).
#
# This file MUST load synchronously, AFTER the forge plugin has defined
# `forge-accept-line` -- otherwise we can't wrap it.  Turbo-mode (zi wait)
# breaks ZLE widget re-registration, so don't.

emulate -L zsh
setopt local_options extended_glob no_aliases

FORGE_HISTFILE="${FORGE_HISTFILE:-${XDG_STATE_HOME:-$HOME/.local/state}/forge/command_history}"
FORGE_HISTSIZE="${FORGE_HISTSIZE:-100000}"
mkdir -p -- "${FORGE_HISTFILE:h}"
# Pre-create the histfile so the first `>>` from _forge_history_append works
# even under `setopt noclobber` + zsh's default `no_append_create`.
[[ -e "$FORGE_HISTFILE" ]] || : >| "$FORGE_HISTFILE"

# ── _forge_history_append <command> ───────────────────────────────────────
# Append a TSV entry: epoch-seconds \t cwd \t command.  Embedded newlines are
# escaped as literal `\n` so each entry stays on one line.
_forge_history_append() {
    # Reset to zsh defaults inside the function so the append works regardless
    # of the caller's `noclobber` / `no_append_create` settings.
    emulate -L zsh
    local cmd="$1"
    [[ -z "$cmd" ]] && return
    local one_line="${cmd//$'\n'/\\n}"
    printf '%s\t%s\t%s\n' "$EPOCHSECONDS" "$PWD" "$one_line" >> "$FORGE_HISTFILE"
}
# zsh/datetime gives us $EPOCHSECONDS without forking date(1)
zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null

# ── Wrap forge-accept-line to log : prompts ──────────────────────────────
# The forge zsh plugin defines forge-accept-line; we wrap it so every `: `
# accepted in ZLE is logged with a real timestamp + cwd.
if (( ${+functions[forge-accept-line]} )); then
    if ! (( ${+functions[_forge_accept_line_orig]} )); then
        functions[_forge_accept_line_orig]="${functions[forge-accept-line]}"
    fi
    forge-accept-line() {
        if [[ "$BUFFER" == :* ]]; then
            _forge_history_append "$BUFFER"
        fi
        _forge_accept_line_orig "$@"
    }
    zle -N forge-accept-line
else
    print -u2 -P '%F{yellow}[forge-history]%f forge-accept-line not found -- : history logging disabled (load this snippet AFTER `forge zsh plugin`)'
fi

# ── Internal: format an epoch into a stable 16-char column ───────────────
# Output format: `YYYY-MM-DD HH:MM`.  Falls back to `----------------`
# when ts is 0/empty.  Uses the strftime builtin (no date(1) fork).
_forge_fmt_date() {
    local ts="$1"
    if [[ -z "$ts" || "$ts" -le 0 ]]; then
        print -- '----------------'
        return
    fi
    local out
    strftime -s out '%Y-%m-%d %H:%M' "$ts" 2>/dev/null \
        || out=$(date -r "$ts" '+%Y-%m-%d %H:%M' 2>/dev/null) \
        || out=$(date -d "@$ts" '+%Y-%m-%d %H:%M' 2>/dev/null) \
        || out='----------------'
    print -- "$out"
}

# ── _forge_collect_history → reply=(ts<TAB>cmd ...) (ts ASC) ─────────────
# Merges all sources, dedupes by command (last occurrence wins so the most
# recent timestamp is kept), and returns sorted ASC by timestamp.
_forge_collect_history() {
    local -a raw=()
    local line ts cwd cmd payload meta

    # 1) ~/forge/.forge_history
    local forge_native="$HOME/forge/.forge_history"
    if [[ -r "$forge_native" ]]; then
        local file_ts total i=0 synth
        file_ts=$(zstat +mtime -- "$forge_native" 2>/dev/null) \
            || file_ts=$(stat -f '%m' -- "$forge_native" 2>/dev/null) \
            || file_ts=$(stat -c '%Y' -- "$forge_native" 2>/dev/null) \
            || file_ts=0
        total=$(wc -l < "$forge_native")
        (( total < 1 )) && total=1
        # Synthesize per-line timestamps so display order matches file order:
        # newest line = file_ts, each older line = 60s earlier.
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            i=$((i + 1))
            synth=$(( file_ts - (total - i) * 60 ))
            (( synth < 0 )) && synth=0
            # Strip a leading `: ` if forge ever leaves one in; we add it back on display.
            local body="${line#: }"
            raw+=("${synth}"$'\t'"${body}")
        done < "$forge_native"
    fi

    # 2) $FORGE_HISTFILE (TSV, real timestamps)
    if [[ -r "$FORGE_HISTFILE" ]]; then
        while IFS=$'\t' read -r ts cwd cmd; do
            [[ -z "$cmd" ]] && continue
            local body="${cmd#: }"
            body="${body#:}"   # tolerate `:foo` legacy entries
            raw+=("${ts}"$'\t'"${body}")
        done < "$FORGE_HISTFILE"
    fi

    # 3) $HISTFILE -- extended_history `: TS:DUR;: ...` lines
    if [[ -n "$HISTFILE" && -r "$HISTFILE" ]]; then
        while IFS= read -r line; do
            # Match `: <digits>:<digits>;: <text>`
            [[ "$line" == ': '<->':'<->';: '* ]] || continue
            meta="${line%%;*}"             # `: 1234567890:0`
            payload="${line#*;}"           # `: actual prompt`
            ts="${${meta#: }%%:*}"         # 1234567890
            local body="${payload#: }"
            raw+=("${ts}"$'\t'"${body}")
        done < "$HISTFILE"
    fi

    # 4) atuin DB
    local atuin_db="$HOME/.local/share/atuin/history.db"
    if [[ -r "$atuin_db" ]] && (( ${+commands[sqlite3]} )); then
        # atuin stores timestamps in nanoseconds since epoch.  Use ASCII
        # 0x1f / 0x1e (record/field separator) so multi-line commands stay
        # in one record.  NB: zsh's (s:STR:) flag does NOT interpret $'..'
        # escapes when written inline -- we have to put the separators in
        # variables and use (ps:$var:).
        #
        # The atuin daemon writes to this DB concurrently. Without a busy
        # timeout we hit SQLITE_BUSY on lock contention and silently get
        # an empty result. `.timeout 2000` waits up to 2s for the writer
        # to release the lock before giving up.
        local fs=$'\x1f' rs=$'\x1e'
        local atuin_out
        atuin_out=$(sqlite3 -separator "$fs" -newline "$rs" \
            -cmd '.timeout 2000' \
            "$atuin_db" \
            "SELECT timestamp/1000000000, command FROM history WHERE command LIKE ': %' ORDER BY timestamp ASC;" \
            2>/dev/null)
        if [[ -n "$atuin_out" ]]; then
            local -a recs=("${(@ps:$rs:)atuin_out}")
            local rec
            for rec in "${recs[@]}"; do
                [[ -z "$rec" ]] && continue
                ts="${rec%%${fs}*}"
                cmd="${rec#*${fs}}"
                local body="${cmd#: }"
                raw+=("${ts}"$'\t'"${body}")
            done
        fi
    fi

    # Sort ASC by leading timestamp (numeric).  `(n)` flag = numeric sort,
    # `(o)` = ascending.  Splits on \n -- entries don't contain literal \n
    # because the TSV writer escaped them.
    local -a sorted=("${(@on)raw}")

    # Dedupe: keep last occurrence (newest ts wins).  Walk from end to start.
    # NB: do NOT write `local i body_only` -- $i may already be local with a
    # value (set by the forge_native loop above), and `local NAME` without
    # an explicit `=VALUE` makes typeset print `NAME=value` to STDOUT,
    # which would break $(_forge_collect_history) callers.  Always init.
    local -A seen=()
    local -a unique=()
    local body_only=''
    local idx=0
    for (( idx=${#sorted[@]}; idx>=1; idx-- )); do
        body_only="${sorted[idx]#*$'\t'}"
        (( ${+seen[$body_only]} )) && continue
        seen[$body_only]=1
        unique=("${sorted[idx]}" "${unique[@]}")
    done

    reply=("${unique[@]}")
}

# ── forge-hist: list/print history (TTY usage, not a ZLE widget) ──────────
forge-hist() {
    local show_all=false count=50 pattern=""
    while (( $# )); do
        case "$1" in
            -a|--all) show_all=true; shift ;;
            -n)       count="$2"; shift 2 ;;
            *)        pattern="$1"; shift ;;
        esac
    done

    local -a reply=()
    _forge_collect_history
    if (( ${#reply[@]} == 0 )); then
        print -u2 -- 'No forge history yet.'
        return 0
    fi

    local -a output=()
    local entry ts body when
    for entry in "${reply[@]}"; do
        ts="${entry%%$'\t'*}"
        body="${entry#*$'\t'}"
        if [[ -n "$pattern" && "$body" != *"$pattern"* ]]; then
            continue
        fi
        when=$(_forge_fmt_date "$ts")
        output+=("$(printf '\033[2m%s\033[0m  %s' "$when" "$body")")
    done

    local total=${#output[@]}
    if (( total == 0 )); then
        print -u2 -- 'No matching entries.'
        return 0
    fi
    if $show_all || (( total <= count )); then
        print -l -- "${output[@]}"
    else
        print -l -- "${output[@]: -$count}"
    fi
}

# ── forge-hist-search: fzf picker, works as ZLE widget OR plain function ──
forge-hist-search() {
    if ! (( ${+commands[fzf]} )); then
        zle -M 'fzf is required for forge-hist-search.' 2>/dev/null \
            || print -u2 -- 'fzf is required for forge-hist-search.'
        return 1
    fi

    local -a reply=()
    _forge_collect_history
    if (( ${#reply[@]} == 0 )); then
        zle -M 'No forge history yet.' 2>/dev/null \
            || print -u2 -- 'No forge history yet.'
        return 0
    fi

    # Build display lines:
    #   <YYYY-MM-DD HH:MM>  : <first line of body>[ […] if multi-line]\x1f<full body>
    #
    # Field 1 is what fzf shows AND matches against (--with-nth=1 + --nth=1).
    # Field 2 carries the original body so we can:
    #   - restore the full multi-line content into BUFFER on Enter,
    #   - render it in the (toggled-on-demand) preview pane.
    #
    # Multi-line preview rule: take only the FIRST line of the body and append
    # ` […]` if there was more.  The previous version sprinkled `⏎` glyphs
    # through every multi-line entry which was the main source of visual
    # noise in the result list.  One uniform-looking row per entry is much
    # easier on the eye and on word-AND filtering.
    local -a fzf_input=()
    local entry ts body when normalized first_line oneline
    for entry in "${reply[@]}"; do
        ts="${entry%%$'\t'*}"
        body="${entry#*$'\t'}"
        when=$(_forge_fmt_date "$ts")
        # Forge stores newlines as literal `\n`; normalise both forms to real
        # newlines so the truncation logic is uniform.
        normalized="${body//\\n/$'\n'}"
        first_line="${normalized%%$'\n'*}"
        if [[ "$normalized" == *$'\n'* ]]; then
            oneline="${first_line} […]"
        else
            oneline="$first_line"
        fi
        fzf_input+=("${when}  : ${oneline}"$'\x1f'"${body}")
    done

    # Use BUFFER (minus a leading `:` / `: `) as the initial fzf query,
    # so C-f mid-typing narrows the picker.
    local query="$BUFFER"
    query="${query#:}"
    query="${query# }"

    # ── Why this fzf invocation looks the way it does ────────────────────
    # The user's mental model:
    #   "type words → narrow the list. WORDWISE not letterwise."
    # fzf's `--exact` does exactly that natively: each space-separated token
    # is an AND-combined substring requirement; no fuzzy letter scatter.
    # No awk pre-filter, no change:reload, no temp files needed.
    #
    # Knobs that matter:
    #   --tac           input is sorted ASC, --tac shows newest at top
    #   --exact         substring (not fuzzy); space = AND between tokens
    #   --no-sort       keep input order; an empty query stays newest-first
    #                   AND a non-empty query just hides non-matching rows
    #                   without reshuffling the survivors. Predictable.
    #   --tiebreak=index  belt-and-braces in case --no-sort is overridden
    #   --nth=1         match ONLY on the visible field (everything before
    #                   \x1f).  Without this, fzf silently matches on the
    #                   hidden full-body field too — which is the "I typed
    #                   an exact substring and the list did not shrink"
    #                   symptom from the previous version.
    #   --with-nth=1    show ONLY field 1 in the row.
    #   --info=inline-right  match counter on the prompt line (no extra row).
    #   --layout=reverse     prompt on top, results below.
    #   --height=80%         leaves the surrounding shell context visible.
    #   preview pane    HIDDEN by default (Ctrl-/ toggles).  For the rare
    #                   multi-line prompt you want to peek at before pressing
    #                   Enter; for normal use the row itself is enough.
    #   --color         minimal: dim chrome, single accent (cyan) for the
    #                   prompt + cursor.  No bold / no reverse on match
    #                   highlighting — the previous loud highlights added
    #                   to the visual confusion the user complained about.
    local raw_selected
    raw_selected=$(printf '%s\n' "${fzf_input[@]}" | fzf \
        --tac \
        --exact \
        --no-sort \
        --tiebreak=index \
        --prompt='forge ❯ ' \
        --header='type words (space = AND) — newest first — Ctrl-/ toggles preview' \
        --delimiter=$'\x1f' \
        --with-nth=1 \
        --nth=1 \
        --query="$query" \
        --preview='printf "%s" {2} | sed "s/\\\\n/\n/g"' \
        --preview-window='down:40%:wrap:hidden:border-top' \
        --bind='ctrl-/:toggle-preview' \
        --height='80%' \
        --layout=reverse \
        --info=inline-right \
        --color='hl:cyan,hl+:cyan,info:dim,prompt:cyan,pointer:cyan,marker:cyan,header:dim,border:dim,gutter:-1') \
        || raw_selected=''

    if [[ -z "$raw_selected" ]]; then
        if [[ -n "$WIDGET" ]]; then
            zle reset-prompt
            zle redisplay
        fi
        return 0
    fi

    # Recover the full body from field 2.
    local restored="${raw_selected#*$'\x1f'}"
    # Convert literal `\n` back to real newlines (forge stores them escaped).
    restored="${restored//\\n/$'\n'}"

    if [[ -n "$WIDGET" ]]; then
        BUFFER=": $restored"
        CURSOR=${#BUFFER}
        zle reset-prompt
        zle redisplay
    else
        print -z -- ": $restored"
    fi
}
zle -N forge-hist-search

# ── C-f: forge-hist-search ────────────────────────────────────────────────
# Fires unconditionally -- the user uses C-f only for forge history search.
# (forward-char is still reachable as a fallback widget; remove this if you
#  want the empty-buffer-only variant.)
_forge_ctrl_f() {
    zle forge-hist-search
}
zle -N _forge_ctrl_f
bindkey '^F' _forge_ctrl_f

# Make zsh-autosuggestions clear its ghost text when our widgets fire,
# otherwise the suggestion sits on top of the new BUFFER until next keystroke.
if [[ -n "${ZSH_AUTOSUGGEST_CLEAR_WIDGETS:-}" ]]; then
    ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(forge-hist-search _forge_ctrl_f)
fi
