#!/bin/bash

# Claude Status Line - Design #23
# Three-line status with rounded box structure and dynamic coloring

# ============================================================================
# Color definitions (Gruvbox Dark palette)
# ============================================================================
COLOR_FG0='\033[38;2;251;241;199m'      # #fbf1c7 - light foreground
COLOR_FG4='\033[38;2;168;153;132m'      # #a89984 - gray foreground (muted)
COLOR_DIM='\033[38;2;124;111;100m'      # #7c6f64 - dim foreground
COLOR_BG1='\033[48;2;60;56;54m'         # #3c3836 - dark background
COLOR_BG3='\033[48;2;102;92;84m'        # #665c54 - medium background
COLOR_BLUE='\033[38;2;69;133;136m'      # #458588 - blue
COLOR_AQUA='\033[38;2;104;157;106m'     # #689d6a - aqua
COLOR_GREEN='\033[38;2;152;151;26m'     # #98971a - green
COLOR_ORANGE='\033[38;2;214;93;14m'     # #d65d0e - orange
COLOR_PURPLE='\033[38;2;177;98;134m'    # #b16286 - purple
COLOR_RED='\033[38;2;204;36;29m'        # #cc241d - red
COLOR_YELLOW='\033[38;2;215;153;33m'    # #d79921 - yellow
RESET='\033[0m'

# Box drawing characters (dimmed)
BOX_TOP="${COLOR_DIM}╭─${RESET}"
BOX_MID="${COLOR_DIM}│${RESET}"
BOX_BOT="${COLOR_DIM}╰─${RESET}"
SEP_DASH="${COLOR_DIM}─${RESET}"
SEP_DOT="${COLOR_DIM}·${RESET}"

# ============================================================================
# Test JSON data for debugging
# ============================================================================
TEST_JSON='{
  "hook_event_name": "Status",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/home/user/projects/spdcalc",
  "model": {
    "id": "claude-opus-4-1",
    "display_name": "opus"
  },
  "workspace": {
    "current_dir": "/home/user/projects/spdcalc",
    "project_dir": "/home/user/projects/spdcalc"
  },
  "version": "1.0.80",
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000
  }
}'

# Test usage data with reset times (for --test mode)
TEST_USAGE='{
  "five_hour": {
    "utilization": 73,
    "resets_at": "2026-02-03T22:00:00.210924+00:00"
  },
  "seven_day": {
    "utilization": 87,
    "resets_at": "2026-02-07T11:00:00.123456+00:00"
  }
}'

# ============================================================================
# Input handling
# ============================================================================
DEBUG=false
if [ "$1" = "--test" ]; then
    input="$TEST_JSON"
    [ "$2" = "--debug" ] && DEBUG=true
elif [ "$1" = "--debug" ]; then
    DEBUG=true
    input=$(cat)
else
    input=$(cat)
fi

# ============================================================================
# Extract values from JSON with defaults
# ============================================================================
model_name=$(echo "$input" | jq -r '.model.display_name // "unknown"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
used_tokens_percent=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Ensure numeric values
context_size=${context_size:-200000}
input_tokens=${input_tokens:-0}
output_tokens=${output_tokens:-0}
[[ "$context_size" =~ ^[0-9]+$ ]] || context_size=200000
[[ "$input_tokens" =~ ^[0-9]+$ ]] || input_tokens=0
[[ "$output_tokens" =~ ^[0-9]+$ ]] || output_tokens=0

# Calculate total context usage
total_tokens=$((input_tokens + output_tokens))

# ============================================================================
# Project and Git info
# ============================================================================

# Project name from git remote, with fallback to directory name
project_name=""
if [ "$1" = "--test" ]; then
    project_name="spdcalc"
elif command -v git &>/dev/null; then
    remote_url=$(git -C "$current_dir" remote get-url origin 2>/dev/null)
    if [ -n "$remote_url" ]; then
        project_name=$(basename -s .git "$remote_url")
    fi
fi
if [ -z "$project_name" ]; then
    if [ -n "$project_dir" ] && [ "$project_dir" != "null" ]; then
        project_name=$(basename "$project_dir")
    else
        project_name=$(basename "$current_dir")
    fi
fi

# Git branch
git_branch=""
if [ "$1" = "--test" ]; then
    git_branch="main"
elif command -v git &>/dev/null && git -C "$current_dir" rev-parse --git-dir &>/dev/null 2>&1; then
    git_branch=$(git -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Git status (staged and unstaged changes)
git_staged=0
git_unstaged=0
if [ "$1" = "--test" ]; then
    git_staged=3
    git_unstaged=2
elif command -v git &>/dev/null && [ -n "$git_branch" ]; then
    # Count staged changes
    git_staged=$(git -C "$current_dir" diff --cached --numstat 2>/dev/null | wc -l)
    # Count unstaged changes
    git_unstaged=$(git -C "$current_dir" diff --numstat 2>/dev/null | wc -l)
fi

# ============================================================================
# Formatting functions
# ============================================================================

# Format number with K/M suffix
format_number() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        local whole=$((num / 1000000))
        local frac=$(( (num % 1000000) / 100000 ))
        if [ "$frac" -gt 0 ]; then
            echo "${whole}.${frac}M"
        else
            echo "${whole}M"
        fi
    elif [ "$num" -ge 1000 ]; then
        local whole=$((num / 1000))
        local frac=$(( (num % 1000) / 100 ))
        if [ "$frac" -gt 0 ]; then
            echo "${whole}.${frac}k"
        else
            echo "${whole}k"
        fi
    else
        echo "$num"
    fi
}

# Generate usage progress bar with position-based coloring
# Usage: usage_progress_bar <used_percentage>
# Segments 1-5: aqua, 6-8: yellow, 9-10: red
usage_progress_bar() {
    local used_pct=$1
    local width=10

    # Calculate filled segments (round up)
    local filled=$(( (used_pct + 9) / 10 ))
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0

    local bar=""
    for ((i=1; i<=width; i++)); do
        if [ "$i" -le "$filled" ]; then
            # Filled segment - color based on position
            if [ "$i" -le 5 ]; then
                bar+="${COLOR_AQUA}▰${RESET}"
            elif [ "$i" -le 8 ]; then
                bar+="${COLOR_YELLOW}▰${RESET}"
            else
                bar+="${COLOR_RED}▰${RESET}"
            fi
        else
            # Empty segment
            bar+="${COLOR_DIM}▱${RESET}"
        fi
    done

    printf "%b" "$bar"
}

# Get color for used percentage text
# <50% used: aqua, 50-80%: yellow, >80%: red
used_pct_color() {
    local used=$1
    if [ "$used" -lt 50 ]; then
        echo "$COLOR_AQUA"
    elif [ "$used" -lt 80 ]; then
        echo "$COLOR_YELLOW"
    else
        echo "$COLOR_RED"
    fi
}

# Get color for context window size
# <120k: blue, 120k-160k: yellow, >160k: red
context_color() {
    local tokens=$1
    if [ "$tokens" -lt 120000 ]; then
        echo "$COLOR_BLUE"
    elif [ "$tokens" -lt 160000 ]; then
        echo "$COLOR_YELLOW"
    else
        echo "$COLOR_RED"
    fi
}

# Format reset time for 5-hour limit (T-2h · 17:00)
format_5h_reset() {
    local reset_iso=$1
    local now=$(date +%s)

    # Convert ISO 8601 to Unix timestamp
    local reset_timestamp=$(date -d "$reset_iso" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$reset_iso" | cut -d. -f1)" +%s 2>/dev/null)

    if [ -z "$reset_timestamp" ]; then
        echo "error"
        return
    fi

    local diff=$((reset_timestamp - now))

    if [ "$diff" -lt 0 ]; then
        echo "reset passed"
        return
    fi

    # Calculate time until reset
    local hours=$((diff / 3600))
    local mins=$(( (diff % 3600) / 60 ))

    local time_until
    if [ "$hours" -gt 0 ]; then
        time_until="T-${hours}h"
    else
        time_until="T-${mins}m"
    fi

    # Get reset time in HH:MM format (local time)
    local reset_time=$(date -d "$reset_iso" +"%H:%M" 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$reset_iso" | cut -d. -f1)" +"%H:%M" 2>/dev/null)

    echo "${time_until} · ${reset_time}"
}

# Format reset time for 7-day limit (Sat 11:00)
format_7d_reset() {
    local reset_iso=$1

    # Get day and time (local time)
    local reset_day=$(date -d "$reset_iso" +"%a" 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$reset_iso" | cut -d. -f1)" +"%a" 2>/dev/null)
    local reset_time=$(date -d "$reset_iso" +"%H:%M" 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$reset_iso" | cut -d. -f1)" +"%H:%M" 2>/dev/null)

    echo "${reset_day} ${reset_time}"
}

# ============================================================================
# Usage limits (via Anthropic OAuth API)
# ============================================================================
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CREDENTIALS_FILE="$CLAUDE_DIR/.credentials.json"
USAGE_CACHE_FILE="$CLAUDE_DIR/.usage_cache.json"
CACHE_MAX_AGE=60

get_access_token() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null
    fi
}

fetch_usage() {
    local token="$1"
    [ -z "$token" ] && return 1

    local response=$(curl -s --max-time 5 \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.0.31" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour or .seven_day' &>/dev/null; then
        echo "{\"timestamp\": $(date +%s), \"data\": $response}" > "$USAGE_CACHE_FILE"
        echo "$response"
        return 0
    fi
    return 1
}

get_usage() {
    local now=$(date +%s)
    local cached_time=0
    local cached_data=""

    if [ -f "$USAGE_CACHE_FILE" ]; then
        cached_time=$(jq -r '.timestamp // 0' "$USAGE_CACHE_FILE" 2>/dev/null)
        cached_data=$(jq '.data // empty' "$USAGE_CACHE_FILE" 2>/dev/null)
    fi

    local age=$((now - cached_time))

    if [ "$age" -lt "$CACHE_MAX_AGE" ] && [ -n "$cached_data" ] && [ "$cached_data" != "null" ]; then
        echo "$cached_data"
        return 0
    fi

    local token=$(get_access_token)
    if [ -n "$token" ]; then
        local fresh=$(fetch_usage "$token")
        if [ -n "$fresh" ]; then
            echo "$fresh"
            return 0
        fi
    fi

    if [ -n "$cached_data" ] && [ "$cached_data" != "null" ]; then
        echo "$cached_data"
        return 0
    fi

    return 1
}

# ============================================================================
# Format display values
# ============================================================================

context_display=$(echo "${used_tokens_percent}%")
context_max_display=$(format_number "$context_size")
input_display=$(format_number "$input_tokens")
output_display=$(format_number "$output_tokens")

# Context color based on total tokens
ctx_color=$(context_color "$total_tokens")

# ============================================================================
# Get and format usage limits
# ============================================================================
five_hour_bar=""
five_hour_pct=""
seven_day_bar=""
seven_day_pct=""

# Get usage data (use test data in test mode)
if [ "$1" = "--test" ]; then
    usage_data="$TEST_USAGE"
else
    usage_data=$(get_usage 2>/dev/null)
fi

if [ -n "$usage_data" ]; then
    # Parse utilization (this is USED percentage)
    five_hour_used=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty')
    seven_day_used=$(echo "$usage_data" | jq -r '.seven_day.utilization // empty')

    # Format 5-hour limit
    if [ -n "$five_hour_used" ] && [ "$five_hour_used" != "null" ]; then
        five_hour_used_int=$(printf "%.0f" "$five_hour_used" 2>/dev/null || echo "0")
        five_hour_bar=$(usage_progress_bar "$five_hour_used_int")

        if [ "$five_hour_used_int" -eq 0 ]; then
            five_hour_pct="${COLOR_RED}!!%${RESET}"
        else
            pct_color=$(used_pct_color "$five_hour_used_int")
            five_hour_pct="${pct_color}${five_hour_used_int}%${RESET}"
        fi
    fi

    # Format 7-day limit
    if [ -n "$seven_day_used" ] && [ "$seven_day_used" != "null" ]; then
        seven_day_used_int=$(printf "%.0f" "$seven_day_used" 2>/dev/null || echo "0")
        seven_day_bar=$(usage_progress_bar "$seven_day_used_int")

        if [ "$seven_day_used_int" -eq 0 ]; then
            seven_day_pct="${COLOR_RED}!!%${RESET}"
        else
            pct_color=$(used_pct_color "$seven_day_used_int")
            seven_day_pct="${pct_color}${seven_day_used_int}%${RESET}"
        fi
    fi
fi

# ============================================================================
# Build the status line - Design #23
#
# ╭─ spdcalc ─ main +3 ~2
# │  opus · 12k/200k · ↑2.1k ↓847
# ╰─ 5h ▰▰▰▰▰▰▱▱▱▱ 63% ─ 7d ▰▰▰▰▰▰▰▰▰▱ 87%
# ============================================================================

# --- Line 1: Project context ---
printf "%b " "$BOX_TOP"
printf "${COLOR_AQUA}%s${RESET}" "$project_name"
if [ -n "$git_branch" ]; then
    printf " %b " "$SEP_DASH"
    printf "${COLOR_GREEN}%s${RESET}" "$git_branch"
    # Git changes (only if present)
    if [ "$git_staged" -gt 0 ]; then
        printf " ${COLOR_YELLOW}+%d${RESET}" "$git_staged"
    fi
    if [ "$git_unstaged" -gt 0 ]; then
        printf " ${COLOR_RED}~%d${RESET}" "$git_unstaged"
    fi
fi
printf "\n"

# --- Line 2: Model and tokens ---
printf "%b  " "$BOX_MID"
printf "${COLOR_PURPLE}%s${RESET}" "$model_name"
printf " %b " "$SEP_DOT"
printf "%b%s${RESET}${COLOR_DIM} of %s${RESET}" "$ctx_color" "$context_display" "$context_max_display"
printf " %b " "$SEP_DOT"
printf "${COLOR_ORANGE}↑%s${RESET} ${COLOR_BLUE}↓%s${RESET}" "$input_display" "$output_display"
printf "\n"

# --- Line 3: Usage limits ---
printf "%b " "$BOX_BOT"
if [ -n "$five_hour_bar" ] && [ -n "$seven_day_bar" ]; then
    printf "${COLOR_DIM}5h${RESET} %b %b" "$five_hour_bar" "$five_hour_pct"
    printf " %b " "$SEP_DASH"
    printf "${COLOR_DIM}7d${RESET} %b %b" "$seven_day_bar" "$seven_day_pct"
elif [ -n "$five_hour_bar" ]; then
    printf "${COLOR_DIM}5h${RESET} %b %b" "$five_hour_bar" "$five_hour_pct"
elif [ -n "$seven_day_bar" ]; then
    printf "${COLOR_DIM}7d${RESET} %b %b" "$seven_day_bar" "$seven_day_pct"
else
    printf "${COLOR_DIM}limits unavailable${RESET}"
fi
printf "\n"

# --- Line 4 (conditional): Reset times if usage > 70% ---
if [ -n "$usage_data" ]; then
    # Parse reset timestamps
    five_hour_resets_at=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    seven_day_resets_at=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

    # Check which reset times to show
    show_5h_reset=""
    show_7d_reset=""

    if [ -n "$five_hour_resets_at" ] && [ "$five_hour_resets_at" != "null" ] && [ "$five_hour_used_int" -gt 70 ]; then
        show_5h_reset=$(format_5h_reset "$five_hour_resets_at")
    fi

    if [ -n "$seven_day_resets_at" ] && [ "$seven_day_resets_at" != "null" ] && [ "$seven_day_used_int" -gt 70 ]; then
        show_7d_reset=$(format_7d_reset "$seven_day_resets_at")
    fi

    # Display reset times on a single line
    if [ -n "$show_5h_reset" ] || [ -n "$show_7d_reset" ]; then
        printf "%b" "$COLOR_DIM"

        if [ -n "$show_5h_reset" ]; then
            printf "   ╰─ %s" "$show_5h_reset"
        fi

        if [ -n "$show_7d_reset" ]; then
            # Calculate spacing between 5h and 7d reset displays
            if [ -n "$show_5h_reset" ]; then
                # Both shown: calculate spacing from end of 5h display to 7d position
                # 5h display: "   ╰─ T-3h · 17:00" = 3 + 2 + 1 + length of reset text
                # Need to align 7d's ╰ with position 23
                pct_len=3
                if [ "$five_hour_used_int" -eq 100 ]; then
                    pct_len=4
                fi
                seven_day_pos=$((3 + 3 + 10 + 1 + pct_len + 1 + 1 + 1))
                five_h_display_len=$((3 + 2 + 1 + ${#show_5h_reset}))
                spacing=$((seven_day_pos - five_h_display_len))
                printf "%${spacing}s╰─ %s" "" "$show_7d_reset"
            else
                # Only 7d shown: align with "7d" at position 23
		printf "%23s╰─ %s" "" "$show_7d_reset"
            fi
        fi

        printf "%b\n" "$RESET"
    fi
fi
