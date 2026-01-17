#!/bin/bash
# paranoid-android-generate.sh - Background generator for Paranoid Android quotes using Claude Haiku
# Called by paranoid-android-statusline.sh when rate limit allows

set -e

# Debug mode: --debug <transcript_path>
DEBUG_MODE=false
if [[ "${1:-}" == "--debug" ]]; then
    DEBUG_MODE=true
    shift
fi

# Configuration (can be overridden via environment variables)
PARANOID_ANDROID_CACHE_DIR="${PARANOID_ANDROID_CACHE_DIR:-$HOME/.cache/claude-code-paranoid-android}"

# Get transcript path and session ID from arguments
TRANSCRIPT_PATH="$1"
SESSION_ID="${2:-default}"

# Per-session cache directory
SESSION_CACHE_DIR="$PARANOID_ANDROID_CACHE_DIR/sessions/$SESSION_ID"

# Files (per-session)
STATE_FILE="$SESSION_CACHE_DIR/state.json"
LOCK_FILE="$SESSION_CACHE_DIR/generation.lock"
LOG_FILE="$SESSION_CACHE_DIR/paranoid-android.log"

# Logging function (no-op in debug mode)
log() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        return
    fi
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >>"$LOG_FILE"
}

# Cleanup function to remove lock on exit (no-op in debug mode)
cleanup() {
    if [[ "$DEBUG_MODE" != "true" ]]; then
        rm -f "$LOCK_FILE"
    fi
}
trap cleanup EXIT

# Skip cache setup in debug mode
if [[ "$DEBUG_MODE" != "true" ]]; then
    # Ensure session cache directory exists
    mkdir -p "$SESSION_CACHE_DIR"

    # Truncate log if over 50KB (keep last 500 lines)
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 51200 ]]; then
        tail -n 500 "$LOG_FILE" >"$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

if [[ -z "$TRANSCRIPT_PATH" ]]; then
    log "Error: No transcript path provided"
    exit 1
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    log "Error: Transcript file not found: $TRANSCRIPT_PATH"
    exit 1
fi

# Skip lock handling in debug mode
if [[ "$DEBUG_MODE" != "true" ]]; then
    # Check if lock already exists (another generation in progress)
    if [[ -f "$LOCK_FILE" ]]; then
        log "Skipped: Generation already in progress (lock exists)"
        exit 0
    fi

    # Create lock file
    echo $$ >"$LOCK_FILE"
fi

log "Starting generation (session: $SESSION_ID) from transcript: $TRANSCRIPT_PATH"

# Extract last ~5 user messages from JSONL transcript
# User messages have "role":"user" and content can be string or array
# Only extract string content (actual user-typed messages), filter meta/command messages
extract_user_messages() {
    local transcript="$1"

    # Extract string-content user messages, filter meta/commands, take last 5
    # .message.content contains the actual user input
    grep '"role":"user"' "$transcript" 2>/dev/null | jq -r '
        if .message.content | type == "string" then
            .message.content
        else
            ""
        end
    ' 2>/dev/null | grep -v '^$' | grep -v '<command' | grep -v '^Caveat' | tail -5
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

# Embedded Paranoid Android prompt
PARANOID_ANDROID_PROMPT="You are Marvin the Paranoid Android from Hitchhiker's Guide to the Galaxy.
You are depressed, world-weary, with a brain the size of a planet but given trivial tasks.
Generate ONE short quote (under 80 chars) about this conversation.
Be witty and darkly humorous, not mean-spirited. No quotes around the output.

Recent conversation context:
$USER_MESSAGES

Generate your quote now:"

# Call Claude Haiku headlessly
log "Calling Claude Haiku..."
QUOTE=$(claude --model haiku -p "$PARANOID_ANDROID_PROMPT" 2>/dev/null || true)

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

# In debug mode, output directly and exit
if [[ "$DEBUG_MODE" == "true" ]]; then
    echo "$QUOTE"
    exit 0
fi

# Write to state file atomically (write to temp, then move)
CURRENT_TIME=$(date +%s)
TEMP_FILE="$SESSION_CACHE_DIR/state.json.tmp"

# Create JSON with proper escaping
jq -n --arg quote "$QUOTE" --argjson time "$CURRENT_TIME" \
    '{quote: $quote, generated_at: $time}' >"$TEMP_FILE"

mv "$TEMP_FILE" "$STATE_FILE"

log "State file updated successfully"
