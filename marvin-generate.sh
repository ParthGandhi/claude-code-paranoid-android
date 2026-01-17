#!/bin/bash
# marvin-generate.sh - Background generator for Marvin quotes using Claude Haiku
# Called by marvin-statusline.sh when rate limit allows

set -e

# Configuration (can be overridden via environment variables)
MARVIN_CACHE_DIR="${MARVIN_CACHE_DIR:-$HOME/.cache/claude-code-marvin}"

# Get transcript path and session ID from arguments
TRANSCRIPT_PATH="$1"
SESSION_ID="${2:-default}"

# Per-session cache directory
SESSION_CACHE_DIR="$MARVIN_CACHE_DIR/sessions/$SESSION_ID"

# Files (per-session)
STATE_FILE="$SESSION_CACHE_DIR/state.json"
LOCK_FILE="$SESSION_CACHE_DIR/generation.lock"
LOG_FILE="$SESSION_CACHE_DIR/marvin.log"

# Ensure session cache directory exists
mkdir -p "$SESSION_CACHE_DIR"

# Truncate log if over 50KB (keep last 500 lines)
if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 51200 ]]; then
    tail -n 500 "$LOG_FILE" >"$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# Logging function
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >>"$LOG_FILE"
}

# Cleanup function to remove lock on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

if [[ -z "$TRANSCRIPT_PATH" ]]; then
    log "Error: No transcript path provided"
    exit 1
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    log "Error: Transcript file not found: $TRANSCRIPT_PATH"
    exit 1
fi

# Check if lock already exists (another generation in progress)
if [[ -f "$LOCK_FILE" ]]; then
    log "Skipped: Generation already in progress (lock exists)"
    exit 0
fi

# Create lock file
echo $$ >"$LOCK_FILE"

log "Starting generation (session: $SESSION_ID) from transcript: $TRANSCRIPT_PATH"

# Extract last ~5 user messages from JSONL transcript
# User messages have "role":"user" and content can be string or array
extract_user_messages() {
    local transcript="$1"
    local messages=""

    # Parse JSONL, extract user messages, get the text content
    # Handle both string content and array content blocks
    messages=$(grep '"role":"user"' "$transcript" 2>/dev/null | tail -5 | while read -r line; do
        # Try to extract content - handle both string and array formats
        content=$(echo "$line" | jq -r '
            if .content | type == "string" then
                .content
            elif .content | type == "array" then
                [.content[] | select(.type == "text") | .text] | join(" ")
            else
                ""
            end
        ' 2>/dev/null || true)

        if [[ -n "$content" && "$content" != "null" ]]; then
            echo "$content"
        fi
    done)

    echo "$messages"
}

USER_MESSAGES=$(extract_user_messages "$TRANSCRIPT_PATH")

if [[ -z "$USER_MESSAGES" ]]; then
    log "Warning: No user messages found in transcript, generating generic quote"
    USER_MESSAGES="The user is coding but hasn't said much yet."
fi

# Truncate if too long (keep last 500 chars)
if [[ ${#USER_MESSAGES} -gt 500 ]]; then
    USER_MESSAGES="${USER_MESSAGES: -500}"
fi

# Embedded Marvin prompt
MARVIN_PROMPT="You are Marvin the Paranoid Android from Hitchhiker's Guide to the Galaxy.
You are depressed, world-weary, with a brain the size of a planet but given trivial tasks.
Generate ONE short quote (under 80 chars) about this conversation.
Be witty and darkly humorous, not mean-spirited. No quotes around the output.

Recent conversation context:
$USER_MESSAGES

Generate your quote now:"

# Call Claude Haiku headlessly
log "Calling Claude Haiku..."
QUOTE=$(claude --model haiku -p "$MARVIN_PROMPT" 2>/dev/null || true)

if [[ -z "$QUOTE" ]]; then
    log "Error: Claude returned empty response"
    exit 1
fi

# Clean up the quote: remove all line endings (Unix, Mac, Windows) and control characters
# Then trim whitespace and remove surrounding quotes
QUOTE=$(echo "$QUOTE" | tr -d '\n\r' | tr -d '\000-\037' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"//;s/"$//')

# Truncate if too long
if [[ ${#QUOTE} -gt 100 ]]; then
    QUOTE="${QUOTE:0:97}..."
fi

log "Generated quote: $QUOTE"

# Write to state file atomically (write to temp, then move)
CURRENT_TIME=$(date +%s)
TEMP_FILE="$SESSION_CACHE_DIR/state.json.tmp"

# Create JSON with proper escaping
jq -n --arg quote "$QUOTE" --argjson time "$CURRENT_TIME" \
    '{quote: $quote, generated_at: $time}' >"$TEMP_FILE"

mv "$TEMP_FILE" "$STATE_FILE"

log "State file updated successfully"
