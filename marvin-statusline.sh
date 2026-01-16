#!/bin/bash
# marvin-statusline.sh - Main entry point for Marvin the Paranoid Android status line
# Displays cached quote and triggers background generation when rate limit allows

set -e

# Configuration (can be overridden via environment variables)
MARVIN_CACHE_DIR="${MARVIN_CACHE_DIR:-$HOME/.cache/claude-code-marvin}"
MARVIN_MIN_INTERVAL="${MARVIN_MIN_INTERVAL:-180}"  # 3 minutes default

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
mkdir -p "$MARVIN_CACHE_DIR"

# Read JSON input from stdin
INPUT=$(cat)

# Extract transcript_path from input JSON
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

# Function to get a random fallback quote
get_fallback_quote() {
    local idx=$((RANDOM % ${#FALLBACK_QUOTES[@]}))
    echo "${FALLBACK_QUOTES[$idx]}"
}

# Function to read cached quote
get_cached_quote() {
    local state_file="$MARVIN_CACHE_DIR/state.json"

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
    local state_file="$MARVIN_CACHE_DIR/state.json"
    local lock_file="$MARVIN_CACHE_DIR/generation.lock"

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

        if [[ $elapsed -lt $MARVIN_MIN_INTERVAL ]]; then
            return 1
        fi
    fi

    return 0
}

# Function to spawn generator in background
spawn_generator() {
    local generator_script="$SCRIPT_DIR/marvin-generate.sh"

    if [[ -x "$generator_script" ]]; then
        # Spawn in background with nohup, redirect all output
        nohup "$generator_script" "$TRANSCRIPT_PATH" > /dev/null 2>&1 &
    fi
}

# Main execution
QUOTE=$(get_cached_quote)

# Output styled quote
echo -e "${STYLE_START}${QUOTE}${STYLE_END}"

# Check if we should trigger generation
if should_generate; then
    spawn_generator
fi
