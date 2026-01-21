#!/bin/bash

# Claude Status Line with Gruvbox Dark colors from Starship
# Matches the color palette from ~/.config/starship.toml

# ============================================================================
# Color definitions (Gruvbox Dark palette)
# ============================================================================
COLOR_FG0='\033[38;2;251;241;199m'      # #fbf1c7 - light foreground
COLOR_FG4='\033[38;2;168;153;132m'      # #a89984 - gray foreground
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
BOLD='\033[1m'
DIM='\033[2m'

# UI Characters
SEP="${COLOR_FG4}│${RESET}"
DOT="${COLOR_FG4}·${RESET}"
ARROW_IN="${COLOR_FG4}↓${RESET}"
ARROW_OUT="${COLOR_FG4}↑${RESET}"
BRANCH_ICON="${COLOR_FG4}${RESET}"

# ============================================================================
# Test JSON data for debugging
# ============================================================================
TEST_JSON='{
  "hook_event_name": "Status",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/home/user/projects/myapp",
  "model": {
    "id": "claude-opus-4-1",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/home/user/projects/myapp",
    "project_dir": "/home/user/projects/myapp"
  },
  "version": "1.0.80",
  "output_style": {
    "name": "default"
  },
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000,
    "used_percentage": 42.5,
    "remaining_percentage": 57.5,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
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
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
used_percent=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Ensure numeric values have valid defaults
context_size=${context_size:-0}
input_tokens=${input_tokens:-0}
output_tokens=${output_tokens:-0}
used_percent=${used_percent:-0}

# Convert to integers for comparison (handle empty/null)
[[ "$context_size" =~ ^[0-9]+$ ]] || context_size=0
[[ "$input_tokens" =~ ^[0-9]+$ ]] || input_tokens=0
[[ "$output_tokens" =~ ^[0-9]+$ ]] || output_tokens=0

# ============================================================================
# Derived values
# ============================================================================

# Project name from git remote, with fallback to directory name
project_name=""
if [ "$1" = "--test" ]; then
    project_name="myapp"  # Test data
elif command -v git &>/dev/null; then
    # Try to get repo name from git remote URL
    remote_url=$(git -C "$current_dir" remote get-url origin 2>/dev/null)
    if [ -n "$remote_url" ]; then
        # Parse repo name from URL (handles both SSH and HTTPS formats)
        # git@github.com:user/repo.git -> repo
        # https://github.com/user/repo.git -> repo
        project_name=$(basename -s .git "$remote_url")
    fi
fi
# Fallback to directory name
if [ -z "$project_name" ]; then
    if [ -n "$project_dir" ] && [ "$project_dir" != "null" ]; then
        project_name=$(basename "$project_dir")
    else
        project_name=$(basename "$current_dir")
    fi
fi

# Shorten current_dir (replace HOME with ~)
current_dir_display="${current_dir/#$HOME/~}"

# Get git branch (if in a git repo)
git_branch=""
if [ "$1" = "--test" ]; then
    git_branch="main"  # Test data
elif command -v git &>/dev/null; then
    git_branch=$(git -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# ============================================================================
# Formatting functions
# ============================================================================

# Format number with K/M suffix (pure bash, no bc dependency)
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
        echo "$((num / 1000))K"
    else
        echo "$num"
    fi
}

# Generate a mini progress bar (ASCII)
# Usage: progress_bar <percentage> <width> <filled_color>
progress_bar() {
    local percent=$1
    local width=${2:-10}
    local bar_color=$3

    # Calculate filled/empty segments
    local filled_count=$((percent * width / 100))
    [ "$filled_count" -gt "$width" ] && filled_count=$width
    [ "$filled_count" -lt 0 ] && filled_count=0
    local empty_count=$((width - filled_count))

    # Build the bar: = for filled, space for empty
    local filled_bar="" empty_bar=""
    for ((i=0; i<filled_count; i++)); do
        filled_bar+="="
    done
    for ((i=0; i<empty_count; i++)); do
        empty_bar+=" "
    done

    printf "${bar_color}[%s%s]${RESET}" "$filled_bar" "$empty_bar"
}

# ============================================================================
# Format display values
# ============================================================================

context_size_display=$(format_number "$context_size")
input_tokens_display=$(format_number "$input_tokens")
output_tokens_display=$(format_number "$output_tokens")

# Determine context usage color (green -> yellow -> red)
if [[ "$used_percent" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    used_int=$(printf "%.0f" "$used_percent")
    if [ "$used_int" -lt 50 ]; then
        context_color="$COLOR_GREEN"
    elif [ "$used_int" -lt 80 ]; then
        context_color="$COLOR_YELLOW"
    else
        context_color="$COLOR_RED"
    fi
else
    used_int=0
    context_color="$COLOR_GREEN"
fi

# ============================================================================
# Usage limits (via Anthropic OAuth API)
# ============================================================================
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
USAGE_CACHE_FILE="$HOME/.claude/.usage_cache.json"
CACHE_MAX_AGE=60  # seconds

# Get access token from credentials
get_access_token() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null
    fi
}

# Fetch usage from API
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

    # Check if response has expected structure
    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour or .seven_day' &>/dev/null; then
        echo "{\"timestamp\": $(date +%s), \"data\": $response}" > "$USAGE_CACHE_FILE"
        echo "$response"
        return 0
    fi
    return 1
}

# Get usage (from cache or API)
get_usage() {
    local now=$(date +%s)
    local cached_time=0
    local cached_data=""

    # Check cache
    if [ -f "$USAGE_CACHE_FILE" ]; then
        cached_time=$(jq -r '.timestamp // 0' "$USAGE_CACHE_FILE" 2>/dev/null)
        cached_data=$(jq '.data // empty' "$USAGE_CACHE_FILE" 2>/dev/null)
    fi

    local age=$((now - cached_time))

    # Use cache if fresh enough
    if [ "$age" -lt "$CACHE_MAX_AGE" ] && [ -n "$cached_data" ] && [ "$cached_data" != "null" ]; then
        echo "$cached_data"
        return 0
    fi

    # Fetch fresh data
    local token=$(get_access_token)
    if [ -n "$token" ]; then
        local fresh=$(fetch_usage "$token")
        if [ -n "$fresh" ]; then
            echo "$fresh"
            return 0
        fi
    fi

    # Fall back to stale cache
    if [ -n "$cached_data" ] && [ "$cached_data" != "null" ]; then
        echo "$cached_data"
        return 0
    fi

    return 1
}

# Get and format usage display
usage_display=""
usage_data=$(get_usage 2>/dev/null)

if [ -n "$usage_data" ]; then
    # Parse usage values
    five_hour_util=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty')
    seven_day_util=$(echo "$usage_data" | jq -r '.seven_day.utilization // empty')

    five_hour_part=""
    seven_day_part=""

    # Format five hour: 84% (5h)
    if [ -n "$five_hour_util" ] && [ "$five_hour_util" != "null" ]; then
        five_hour_int=$(printf "%.0f" "$five_hour_util" 2>/dev/null || echo "0")
        if [ "$five_hour_int" -lt 50 ] 2>/dev/null; then
            five_hour_color="$COLOR_GREEN"
        elif [ "$five_hour_int" -lt 80 ] 2>/dev/null; then
            five_hour_color="$COLOR_YELLOW"
        else
            five_hour_color="$COLOR_RED"
        fi
        five_hour_part="${five_hour_color}${five_hour_int}%${RESET} ${DIM}${COLOR_FG4}(5h)${RESET}"
    fi

    # Format seven day: 81% (7d)
    if [ -n "$seven_day_util" ] && [ "$seven_day_util" != "null" ]; then
        seven_day_int=$(printf "%.0f" "$seven_day_util" 2>/dev/null || echo "0")
        if [ "$seven_day_int" -lt 50 ] 2>/dev/null; then
            seven_day_color="$COLOR_GREEN"
        elif [ "$seven_day_int" -lt 80 ] 2>/dev/null; then
            seven_day_color="$COLOR_YELLOW"
        else
            seven_day_color="$COLOR_RED"
        fi
        seven_day_part="${seven_day_color}${seven_day_int}%${RESET} ${DIM}${COLOR_FG4}(7d)${RESET}"
    fi

    # Combine: 84% (5h) / 81% (7d)
    if [ -n "$five_hour_part" ] && [ -n "$seven_day_part" ]; then
        usage_display="${five_hour_part} ${DIM}${COLOR_FG4}/${RESET} ${seven_day_part}"
    elif [ -n "$five_hour_part" ]; then
        usage_display="$five_hour_part"
    elif [ -n "$seven_day_part" ]; then
        usage_display="$seven_day_part"
    fi
fi

# ============================================================================
# Build the status line
#
# Design principles:
# - Visual hierarchy: Project context on line 1, session metrics on line 2
# - Grouping: Related items separated by center dots
# - Consistent spacing and alignment
# - Color coding: Green=input, Red=output, context color=usage level
#
# Line 1: [Project] · [Branch] · [Path]
# Line 2: [Model] · [Limits] · [Context Bar + %] · [Tokens In/Out]
# ============================================================================

# --- Line 1: Project context ---
# Project name (prominent)
printf "${COLOR_YELLOW}${BOLD}%s${RESET}" "$project_name"
# Git branch (if available)
if [ -n "$git_branch" ]; then
    printf "  %b ${COLOR_PURPLE}%s${RESET}" "$BRANCH_ICON" "$git_branch"
fi
# Current directory
printf "  ${COLOR_AQUA}%s${RESET}" "$current_dir_display"
printf "\n"

# --- Line 2: Session metrics ---
# Model
printf "${COLOR_ORANGE}${BOLD}%s${RESET}" "$model_name"
# Usage limits
if [ -n "$usage_display" ]; then
    printf "    %b" "$usage_display"
fi
# Context window (progress bar + percentage)
printf "    %b ${context_color}%d%%${RESET} ${DIM}${COLOR_FG4}(%s)${RESET}" "$(progress_bar "$used_int" 10 "$context_color")" "$used_int" "$context_size_display"
# Token usage (in/out with arrows)
printf "    ${COLOR_GREEN}%s${RESET}%b ${COLOR_RED}%s${RESET}%b" "$input_tokens_display" "$ARROW_IN" "$output_tokens_display" "$ARROW_OUT"
printf "\n"
