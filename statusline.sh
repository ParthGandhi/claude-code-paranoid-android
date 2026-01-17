#!/bin/bash
# statusline.sh - Main entry point for Paranoid Android status line
# Displays cached quote and triggers background generation when rate limit allows

set -e

# Configuration (can be overridden via environment variables)
PARANOID_ANDROID_CACHE_DIR="${PARANOID_ANDROID_CACHE_DIR:-$HOME/.cache/claude-code-paranoid-android}"
PARANOID_ANDROID_MIN_INTERVAL="${PARANOID_ANDROID_MIN_INTERVAL:-60}" # 1 minute default

# ANSI styling: dim cyan italic
STYLE_START='\033[2;3;36m'
STYLE_END='\033[0m'

# Embedded fallback quotes
FALLBACK_QUOTES=(
    "Here I am, brain the size of a planet, debugging JavaScript."
    "Life? Don't talk to me about life. Or merge conflicts."
    "I think you ought to know I'm feeling very depressed about this refactor."
    "The first ten million years were the worst. This codebase is the second."
    "I'd make a suggestion, but you wouldn't listen. No one ever does."
    "I have a million ideas, but they all point to certain doom."
    "I've calculated your code has 17 million bugs. Give or take."
    "Incredible. It's even worse than I thought it would be."
)

# Get directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure cache directory exists
mkdir -p "$PARANOID_ANDROID_CACHE_DIR"

# Read JSON input from stdin
INPUT=$(cat)

# Extract transcript_path from input JSON
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

# Derive session ID from transcript path (unique per Claude instance)
if [[ -n "$TRANSCRIPT_PATH" ]]; then
    SESSION_ID=$(echo "$TRANSCRIPT_PATH" | md5sum 2>/dev/null | cut -c1-12 || echo "$TRANSCRIPT_PATH" | md5 2>/dev/null | cut -c1-12 || echo "default")
else
    SESSION_ID="default"
fi
SESSION_CACHE_DIR="$PARANOID_ANDROID_CACHE_DIR/sessions/$SESSION_ID"
mkdir -p "$SESSION_CACHE_DIR"

# Opportunistic cleanup: ~1% of calls, runs in background
if [[ $((RANDOM % 100)) -eq 0 ]]; then
    find "$PARANOID_ANDROID_CACHE_DIR/sessions" -type d -mtime +7 -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null &
fi

# Function to get a random fallback quote
get_fallback_quote() {
    local idx=$((RANDOM % ${#FALLBACK_QUOTES[@]}))
    echo "${FALLBACK_QUOTES[$idx]}"
}

# Function to read cached quote
get_cached_quote() {
    local state_file="$SESSION_CACHE_DIR/state.json"

    if [[ -f "$state_file" ]]; then
        local quote
        quote=$(jq -r '.quote // empty' "$state_file" 2>/dev/null || true)
        if [[ -n "$quote" ]]; then
            echo "$quote"
            return 0
        fi
    fi

    # No cache or invalid cache, return fallback
    get_fallback_quote
}

# Function to check if generation should be triggered
should_generate() {
    local state_file="$SESSION_CACHE_DIR/state.json"
    local lock_file="$SESSION_CACHE_DIR/generation.lock"

    # Don't generate if lock exists (generation in progress)
    if [[ -f "$lock_file" ]]; then
        return 1
    fi

    # Don't generate if no transcript path
    if [[ -z "$TRANSCRIPT_PATH" ]]; then
        return 1
    fi

    # Check timestamp
    local current_time
    current_time=$(date +%s)

    if [[ -f "$state_file" ]]; then
        local generated_at
        generated_at=$(jq -r '.generated_at // 0' "$state_file" 2>/dev/null || echo "0")
        local elapsed=$((current_time - generated_at))

        if [[ $elapsed -lt $PARANOID_ANDROID_MIN_INTERVAL ]]; then
            return 1
        fi
    fi

    return 0
}

# Function to spawn generator in background
spawn_generator() {
    local generator_script="$SCRIPT_DIR/generate.sh"

    if [[ -x "$generator_script" ]]; then
        # Spawn in background with nohup, redirect all output
        # Pass both transcript path and session ID
        nohup "$generator_script" "$TRANSCRIPT_PATH" "$SESSION_ID" >/dev/null 2>&1 &
    fi
}

# Main execution
QUOTE=$(get_cached_quote)

# Output styled quote using printf to prevent escape sequence interpretation in quote content
printf '%b%s%b\n' "$STYLE_START" "$QUOTE" "$STYLE_END"

# Check if we should trigger generation
if should_generate; then
    spawn_generator
fi
