# forge-conversation-resume.zsh -- `fcr` picker to resume a forge session
#
# fcr  Opens an fzf picker over `forge list conversation` output.  Pick a row,
#      hit Enter, and the function execs `forge --conversation-id <UUID>` so
#      you continue the conversation in place.
#
# Design notes (the user asked for a calm TUI):
#   - No fzf "1/123" counter, no scrollbar, no separator line.  Single calm
#     prompt ("forge resume ❯"), short header, rounded border, reverse layout.
#   - Single-letter queries do NOT filter.  fzf's own matching is disabled
#     (--disabled) and an awk pass does the filtering, with a min-query of 2
#     before any narrowing kicks in.  Below 2 chars: full list, newest first.
#   - Match highlighting is done in awk too (so it survives --disabled).
#     The substring is wrapped in a bold-yellow run.
#   - All color escapes come from `tput`, never from hand-written ANSI
#     literals.  Falls back gracefully if tput is missing or stdout is not
#     a tty.
#
# Dependencies: forge, fzf, awk, mktemp.  tput is optional (no color if
# absent).

emulate -L zsh
setopt local_options no_aliases

fcr() {
    emulate -L zsh
    setopt local_options pipefail no_aliases

    # ── deps ──────────────────────────────────────────────────────────────
    if ! (( ${+commands[forge]} )); then
        print -u2 -- 'fcr: forge not found on PATH'
        return 127
    fi
    if ! (( ${+commands[fzf]} && ${+commands[awk]} && ${+commands[mktemp]} )); then
        print -u2 -- 'fcr: requires fzf, awk, mktemp'
        return 127
    fi

    # ── colors via tput (no raw ANSI literals) ────────────────────────────
    # Only colorize when stdout is a tty AND tput is available.  setaf 8
    # (bright black / grey) is widely supported on 256-color terminals; if
    # the terminfo entry doesn't have it, tput prints nothing and we just
    # render plain.
    local C_DATE='' C_ID='' C_HIT='' C_RESET=''
    if [[ -t 1 ]] && (( ${+commands[tput]} )); then
        C_DATE=$(tput setaf 8 2>/dev/null)
        C_ID=$(tput setaf 4 2>/dev/null)
        C_HIT="$(tput bold 2>/dev/null)$(tput setaf 3 2>/dev/null)"
        C_RESET=$(tput sgr0 2>/dev/null)
    fi

    # ── pull conversations ────────────────────────────────────────────────
    local raw
    raw=$(forge list conversation 2>/dev/null) || {
        print -u2 -- 'fcr: `forge list conversation` failed'
        return 1
    }
    if [[ -z "$raw" ]]; then
        print -u2 -- 'fcr: no conversations found'
        return 0
    fi

    local tmpdir
    tmpdir=$(mktemp -d -t fcr.XXXXXX) || return 1

    # ── parse forge's output into TSV: <updated>\t<uuid>\t<title-oneline> ──
    # `forge list conversation` emits stanzas of the form:
    #
    #     <blank>
    #     <uuid>
    #       title   <free-form, sometimes multi-line / multi-paragraph>
    #       updated <e.g. "now" / "12days 22h 25m ago">
    #     <blank>
    #
    # Titles can be enormous (entire prompts get used as titles).  We
    # collapse whitespace, strip control chars, and truncate at 200 cols.
    # NB: forge emits ANSI SGR sequences even when its stdout is a pipe,
    # so we strip them on every line before any matching.
    print -r -- "$raw" | awk '
        BEGIN { id=""; title=""; updated="" }
        { gsub(/\033\[[0-9;]*m/, "") }
        function flush(   t) {
            if (id == "") return
            t = title
            gsub(/[\t\r]/, " ", t)
            gsub(/[[:space:]]+/, " ", t)
            sub(/^[[:space:]]+/, "", t)
            sub(/[[:space:]]+$/, "", t)
            if (t == "") t = "(no title)"
            if (length(t) > 200) t = substr(t, 1, 197) "..."
            if (updated == "") updated = "-"
            printf "%s\t%s\t%s\n", updated, id, t
            id=""; title=""; updated=""
        }
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[[:space:]]*$/ {
            flush()
            id=$1
            next
        }
        /^[[:space:]]+title[[:space:]]+/ {
            sub(/^[[:space:]]+title[[:space:]]+/, "")
            title = (title == "") ? $0 : title " " $0
            next
        }
        /^[[:space:]]+updated[[:space:]]+/ {
            sub(/^[[:space:]]+updated[[:space:]]+/, "")
            updated = $0
            next
        }
        # Continuation lines for huge multi-line titles: anything indented
        # that is not a recognised key gets folded into the title.
        /^[[:space:]]/ {
            if (id != "" && updated == "") {
                title = title " " $0
            }
            next
        }
        END { flush() }
    ' > "$tmpdir/data.tsv"

    if [[ ! -s "$tmpdir/data.tsv" ]]; then
        rm -rf -- "$tmpdir"
        print -u2 -- 'fcr: no conversations parsed'
        return 0
    fi

    # ── render+filter awk: enforces min-query, highlights matches ─────────
    # Rendering and filtering live in the same script so the `change:reload`
    # binding can re-run it on every keystroke with the new query.
    cat > "$tmpdir/render.awk" <<'AWK'
# Vars set via -v:
#   query    -- current fzf query (single-quoted by fzf)
#   min      -- minimum query length before filtering kicks in
#   c_date, c_id, c_hit, c_reset -- tput escape sequences
function highlight(s, q,    out, ls, lq, idx, qlen, head) {
    if (q == "" || c_hit == "") return s
    out = ""; ls = tolower(s); lq = tolower(q); qlen = length(q)
    while (1) {
        idx = index(ls, lq)
        if (idx == 0) { out = out s; break }
        head = substr(s, 1, idx - 1)
        out  = out head c_hit substr(s, idx, qlen) c_reset
        s    = substr(s, idx + qlen)
        ls   = substr(ls, idx + qlen)
    }
    return out
}
function pad(s, w,    n) {
    n = length(s)
    if (n >= w) return substr(s, 1, w)
    while (length(s) < w) s = s " "
    return s
}
BEGIN { FS = "\t" }
{
    updated  = $1
    id       = $2
    title    = $3
    short_id = substr(id, 1, 8)

    if (length(query) >= min) {
        lq = tolower(query)
        if (index(tolower(title),    lq) == 0 && \
            index(tolower(updated),  lq) == 0 && \
            index(tolower(short_id), lq) == 0) next
    }

    # Pad columns BEFORE highlighting so the color escapes (which have
    # zero display width) don't throw off alignment.
    p_date = pad(updated,  22)
    p_id   = pad(short_id,  8)

    h_date  = highlight(p_date, query)
    h_id    = highlight(p_id,   query)
    h_title = highlight(title,  query)

    # Field 1 (full UUID) is hidden via fzf --with-nth=2..; field 2 is the
    # visible row.
    printf "%s\t%s%s%s  %s%s%s  %s\n", \
        id, \
        c_date, h_date, c_reset, \
        c_id,   h_id,   c_reset, \
        h_title
}
AWK

    # ── fzf invocation ────────────────────────────────────────────────────
    # --disabled       : fzf does no matching; awk does it all (so we can
    #                    enforce min-query AND inject our own highlight).
    # --ansi           : honour the tput escapes embedded in the rows.
    # --info=hidden    : kill the "1/123" counter line.
    # --no-scrollbar   : kill the right-edge gutter.
    # --no-separator   : no horizontal line between info area and list.
    # --layout=reverse : prompt at top, list flows downward.
    # --header-first   : header above prompt (calmer than below).
    # --pointer='▌'    : single solid bar, no triangle clutter.
    # --marker=' '     : we don't multi-select.
    # --delimiter=\t   : field 1 = uuid (hidden), field 2 = visible row.
    # --with-nth=2..   : hide field 1 from view but keep it in the output.
    # --bind change    : re-run render.awk with the new query on every keystroke.
    local picked
    picked=$(awk \
            -v query='' -v min=2 \
            -v c_date="$C_DATE" -v c_id="$C_ID" \
            -v c_hit="$C_HIT"   -v c_reset="$C_RESET" \
            -f "$tmpdir/render.awk" "$tmpdir/data.tsv" \
        | fzf \
            --ansi \
            --disabled \
            --info=hidden \
            --no-scrollbar \
            --no-separator \
            --no-mouse \
            --layout=reverse \
            --header-first \
            --height=85% \
            --border=rounded \
            --pointer='▌' \
            --marker=' ' \
            --prompt='forge resume ❯ ' \
            --header='type ≥2 chars to filter · enter resumes · esc cancels' \
            --delimiter=$'\t' \
            --with-nth=2.. \
            --bind="change:reload(awk -v query={q} -v min=2 \
                -v c_date='$C_DATE' -v c_id='$C_ID' \
                -v c_hit='$C_HIT'   -v c_reset='$C_RESET' \
                -f $tmpdir/render.awk $tmpdir/data.tsv)" \
        ) || picked=''

    rm -rf -- "$tmpdir" 2>/dev/null

    [[ -z "$picked" ]] && return 0

    # Field 1 of the picked row is the full UUID.
    local id="${picked%%$'\t'*}"
    if [[ -z "$id" ]]; then
        print -u2 -- 'fcr: failed to extract conversation id'
        return 1
    fi

    print -P -- "%F{8}resuming%f $id"
    forge --conversation-id "$id"
}
