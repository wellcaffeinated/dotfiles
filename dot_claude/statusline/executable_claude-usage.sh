#!/usr/bin/env bash
#
# claude-usage.sh — emit Claude subscription usage (5h / 7d) for a Starship
# custom module. Designed to be portable (chezmoi-friendly: only $HOME-relative
# paths) and to refresh its own cache in the background with NO external cron.
#
# Modes:
#   claude-usage.sh            # render from cache; spawn bg refresh if stale
#   claude-usage.sh bars       # only the 5h/7d gauge line
#   claude-usage.sh resets     # only the reset-times line (empty if usage < 70%)
#   claude-usage.sh demo       # render using built-in example data (no network)
#
# Test/debug hook:
#   CLAUDE_USAGE_FIXTURE=/path/to/usage.json claude-usage.sh
#       -> use that JSON as the usage payload instead of cache/API. Deterministic;
#          used by render-example.sh and for development.
#
set -u

# ============================================================================
# Config (all paths $HOME-relative for portability)
# ============================================================================
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CREDENTIALS_FILE="$CLAUDE_DIR/.credentials.json"
CACHE_FILE="$CLAUDE_DIR/.usage_cache.json"
LOCK_DIR="$CLAUDE_DIR/.usage_refresh.lock"

CACHE_TTL=60        # seconds: cache considered fresh within this window
STALE_LIMIT=900     # seconds: older than this, don't display (too old to trust)
LOCK_TTL=30         # seconds: reap a stale lock left by a crashed refresh
FETCH_TIMEOUT=5     # seconds: curl budget for the background fetch

# ============================================================================
# Gruvbox Dark palette (truecolor ANSI; raw codes so the multi-color gauge
# survives — the Starship module sets unsafe_no_escape = true)
# ============================================================================
C_DIM='\033[38;2;124;111;100m'
C_AQUA='\033[38;2;104;157;106m'
C_GREEN='\033[38;2;152;151;26m'
C_YELLOW='\033[38;2;215;153;33m'
C_RED='\033[38;2;204;36;29m'
RESET='\033[0m'

# ============================================================================
# Built-in example data (demo mode)
# ============================================================================
DEMO_USAGE='{
  "five_hour": { "utilization": 73, "resets_at": "2026-06-29T22:00:00.210924+00:00" },
  "seven_day": { "utilization": 87, "resets_at": "2026-07-04T11:00:00.123456+00:00" }
}'

now() { date +%s; }

# ============================================================================
# Credentials + fetch
# ============================================================================
get_access_token() {
    [ -f "$CREDENTIALS_FILE" ] || return 1
    jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null
}

# Fetch fresh usage and write it to the cache. Runs in the background.
fetch_and_cache() {
    local token response
    token=$(get_access_token) || return 1
    [ -n "$token" ] || return 1

    # Bounded on both connect and total transfer so a stalled/half-open socket
    # can't keep this background process alive longer than the budget.
    response=$(curl -s --connect-timeout "$FETCH_TIMEOUT" --max-time "$FETCH_TIMEOUT" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.0.31" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    # Only touch the cache on a valid payload; write to a temp file and rename so
    # a reader never sees a half-written cache (rename is atomic on one fs).
    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour or .seven_day' >/dev/null 2>&1; then
        local tmp="${CACHE_FILE}.tmp.$$"
        if printf '{"timestamp": %s, "data": %s}\n' "$(now)" "$response" > "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$CACHE_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
        fi
    fi
}

# Spawn a non-blocking, single-flight background refresh. Stdout/stderr/stdin are
# fully redirected so Starship's pipe gets EOF immediately (no hang), and setsid
# (if present) detaches it from this process group so it survives our exit.
trigger_refresh() {
    # Reap a stale lock from a crashed prior refresh.
    if [ -d "$LOCK_DIR" ]; then
        local lock_age=$(( $(now) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0) ))
        [ "$lock_age" -ge "$LOCK_TTL" ] && rmdir "$LOCK_DIR" 2>/dev/null
    fi
    # mkdir is atomic: only one refresher wins.
    mkdir "$LOCK_DIR" 2>/dev/null || return 0

    local runner
    runner() {
        trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
        fetch_and_cache
    }
    if command -v setsid >/dev/null 2>&1; then
        setsid bash -c "$(declare -f now get_access_token fetch_and_cache runner)
            CLAUDE_DIR='$CLAUDE_DIR'; CREDENTIALS_FILE='$CREDENTIALS_FILE'
            CACHE_FILE='$CACHE_FILE'; LOCK_DIR='$LOCK_DIR'; FETCH_TIMEOUT='$FETCH_TIMEOUT'
            runner" >/dev/null 2>&1 < /dev/null &
    else
        ( runner ) >/dev/null 2>&1 < /dev/null &
    fi
    disown 2>/dev/null || true
}

# ============================================================================
# Resolve the usage payload to render.
#   - CLAUDE_USAGE_FIXTURE  -> use that file (deterministic, for tests/dev)
#   - else read cache; trigger a bg refresh when stale/missing
# Echoes the inner usage JSON (the {five_hour,seven_day} object), or nothing.
# ============================================================================
resolve_usage() {
    if [ -n "${CLAUDE_USAGE_FIXTURE:-}" ] && [ -f "$CLAUDE_USAGE_FIXTURE" ]; then
        cat "$CLAUDE_USAGE_FIXTURE"
        return 0
    fi

    local cached_time=0 age=$STALE_LIMIT
    if [ -f "$CACHE_FILE" ]; then
        cached_time=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
        [[ "$cached_time" =~ ^[0-9]+$ ]] || cached_time=0
        age=$(( $(now) - cached_time ))
    fi

    # Kick off a background refresh whenever the cache is past its TTL. This is
    # what keeps the cache warm with no cron: each render that sees stale data
    # quietly refreshes it for the next render.
    if [ "$age" -ge "$CACHE_TTL" ]; then
        trigger_refresh
    fi

    # Display cached data if it isn't ancient.
    if [ -f "$CACHE_FILE" ] && [ "$age" -lt "$STALE_LIMIT" ]; then
        jq -c '.data // empty' "$CACHE_FILE" 2>/dev/null
    fi
}

# ============================================================================
# Formatting
# ============================================================================
usage_progress_bar() {
    local used_pct=$1 width=10 filled bar="" i
    filled=$(( (used_pct + 9) / 10 ))
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    for ((i=1; i<=width; i++)); do
        if [ "$i" -le "$filled" ]; then
            if   [ "$i" -le 5 ]; then bar+="${C_AQUA}▰${RESET}"
            elif [ "$i" -le 8 ]; then bar+="${C_YELLOW}▰${RESET}"
            else                      bar+="${C_RED}▰${RESET}"; fi
        else
            bar+="${C_DIM}▱${RESET}"
        fi
    done
    printf '%b' "$bar"
}

pct_color() {
    local u=$1
    if   [ "$u" -lt 50 ]; then printf '%b' "$C_AQUA"
    elif [ "$u" -lt 80 ]; then printf '%b' "$C_YELLOW"
    else                       printf '%b' "$C_RED"; fi
}

to_int() { printf '%.0f' "$1" 2>/dev/null || echo 0; }

# "T-2h · 17:00" for the 5h window
fmt_5h_reset() {
    local iso=$1 ts diff h m until rt
    ts=$(date -d "$iso" +%s 2>/dev/null) || return 1
    diff=$(( ts - $(now) ))
    [ "$diff" -lt 0 ] && diff=0
    h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
    if [ "$h" -gt 0 ]; then until="T-${h}h"; else until="T-${m}m"; fi
    rt=$(date -d "$iso" +"%H:%M" 2>/dev/null)
    echo "${until} · ${rt}"
}

# "Sat 11:00" for the 7d window
fmt_7d_reset() {
    local iso=$1 d rt
    d=$(date -d "$iso" +"%a" 2>/dev/null)
    rt=$(date -d "$iso" +"%H:%M" 2>/dev/null)
    echo "${d} ${rt}"
}

# Render the gauge line. $1 = usage JSON
render_bars() {
    local data=$1 fh sd fh_i sd_i out=""
    [ -z "$data" ] && return 0
    fh=$(echo "$data" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    sd=$(echo "$data" | jq -r '.seven_day.utilization // empty' 2>/dev/null)

    if [ -n "$fh" ] && [ "$fh" != "null" ]; then
        fh_i=$(to_int "$fh")
        out+="${C_DIM}5h${RESET} $(usage_progress_bar "$fh_i") $(pct_color "$fh_i")${fh_i}%${RESET}"
    fi
    if [ -n "$sd" ] && [ "$sd" != "null" ]; then
        sd_i=$(to_int "$sd")
        [ -n "$out" ] && out+=" ${C_DIM}─${RESET} "
        out+="${C_DIM}7d${RESET} $(usage_progress_bar "$sd_i") $(pct_color "$sd_i")${sd_i}%${RESET}"
    fi
    [ -z "$out" ] && out="${C_DIM}limits unavailable${RESET}"
    printf '%b' "$out"
}

# Box prefix drawn before the bars line (3 visible columns: "╰─ ").
BOX_BOT='╰─ '
BOX_W=3       # visible width of BOX_BOT
LABEL_W=3     # visible width of "5h " / "7d "
BAR_W=10      # constant gauge width (must match usage_progress_bar)

# Render the reset line, only for windows above 70%. $1 = usage JSON.
# Each reset entry is positioned under its own gauge: the 5h reset sits beneath
# the 5h bar, the 7d reset beneath the 7d bar. Column geometry mirrors the bars
# line (box + label + constant-width bar), so the two lines stay aligned.
render_resets() {
    local data=$1 fh sd fh_i sd_i fr sr show5="" show7=""
    [ -z "$data" ] && return 0
    fh=$(echo "$data" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    sd=$(echo "$data" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    fr=$(echo "$data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    sr=$(echo "$data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)
    fh_i=$(to_int "$fh"); sd_i=$(to_int "$sd")

    [ "$fh_i" -gt 70 ] && [ -n "$fr" ] && [ "$fr" != "null" ] && show5="$(fmt_5h_reset "$fr")"
    [ "$sd_i" -gt 70 ] && [ -n "$sr" ] && [ "$sr" != "null" ] && show7="$(fmt_7d_reset "$sr")"
    [ -z "$show5$show7" ] && return 0

    # Column where each bar starts on the bars line (0-indexed).
    local pct5_w=$(( ${#fh_i} + 1 ))                 # "73%" -> 3, "100%" -> 4
    local col_5h=$(( BOX_W + LABEL_W ))              # start of the 5h gauge
    local col_7d=$(( col_5h + BAR_W + 1 + pct5_w + 3 + LABEL_W ))  # +" "+pct+" ─ "+"7d "

    local line="" cur=0 pad
    if [ -n "$show5" ]; then
        pad=$(( col_5h - cur )); [ "$pad" -lt 0 ] && pad=0
        line+=$(printf '%*s' "$pad" '')"$show5"; cur=$(( col_5h + ${#show5} ))
    fi
    if [ -n "$show7" ]; then
        pad=$(( col_7d - cur )); [ "$pad" -lt 1 ] && pad=1
        line+=$(printf '%*s' "$pad" '')"$show7"; cur=$(( col_7d + ${#show7} ))
    fi
    printf '%b' "${C_DIM}${line}${RESET}"
}

# ============================================================================
# Main
# ============================================================================
mode="${1:-render}"
case "$mode" in
    demo)
        data="$DEMO_USAGE"
        printf '%b%b\n' "${C_DIM}${BOX_BOT}${RESET}" "$(render_bars "$data")"
        resets="$(render_resets "$data")"
        [ -n "$resets" ] && printf '%b\n' "$resets"
        ;;
    bars)
        render_bars "$(resolve_usage)"
        ;;
    resets)
        render_resets "$(resolve_usage)"
        ;;
    render|*)
        data="$(resolve_usage)"
        printf '%b%b' "${C_DIM}${BOX_BOT}${RESET}" "$(render_bars "$data")"
        resets="$(render_resets "$data")"
        [ -n "$resets" ] && printf '\n%b' "$resets"
        ;;
esac

# Always succeed: the final command above (the `[ -n "$resets" ]` test) returns
# non-zero when there is no reset line to show (usage < 70%), and Starship's
# custom module silently discards stdout on a non-zero exit — which would drop
# the entire 5h/7d line whenever usage is below the reset threshold.
exit 0
