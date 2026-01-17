# Claude Code Marvin Android

> "Here I am, brain the size of a planet, and you want me to display status messages."

## Overview

A Claude Code status line extension that displays depressed, witty Marvin the Paranoid Android quotes based on your recent conversation, generated using Claude Haiku.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Status Line Script                          │
│  1. Read cached quote from file                                 │
│  2. Display quote                                               │
│  3. If rate limit allows, spawn generator in background         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ spawns (if rate limit allows)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Generator Script                            │
│  1. Read transcript_path from stdin JSON                        │
│  2. Extract last few user messages                              │
│  3. Call `claude --model haiku -p "..."` headless               │
│  4. Write new quote to cache file                               │
└─────────────────────────────────────────────────────────────────┘
```

**Key insight**: Status line receives JSON with `transcript_path` every ~300ms. We use this to:
1. Always display the cached quote (fast)
2. Opportunistically spawn generator in background when rate limit allows

No hooks needed - the status line itself triggers generation.

## File Structure

```
claude-code-marvin/
├── README.md                           # Installation & usage docs
├── LICENSE                             # MIT license
├── install.sh                          # Installer (called by curl)
├── uninstall.sh                        # Clean removal (called by curl)
├── marvin-statusline.sh                # Main script (reads + triggers, includes fallback quotes)
└── marvin-generate.sh                  # Background generator
```

Only 4 functional files (plus README and LICENSE).

**Cache directory** (`~/.cache/claude-code-marvin/`):
```
sessions/
├── [session-id-1]/     # Derived from md5 of transcript_path (12 chars)
│   ├── state.json      # {"quote": "...", "generated_at": 1705412345}
│   ├── generation.lock # Lock file during generation
│   └── marvin.log      # Per-session log file for debugging
├── [session-id-2]/
│   └── ...
└── default/            # Fallback when no transcript_path available
    └── ...
```

**Per-session isolation**: Each Claude Code instance has a unique `transcript_path`. We derive a 12-character session ID from its MD5 hash to create isolated cache directories. This prevents race conditions when multiple Claude instances run simultaneously.

**Automatic cleanup**:
- Session directories older than 7 days are deleted opportunistically (~1% of status line calls)
- Log files are truncated to 500 lines when they exceed 50KB

## Implementation Steps

### 1. Create `marvin-statusline.sh`
**Purpose**: Main entry point - displays cached quote AND triggers background generation

```bash
#!/bin/bash
# 1. Read JSON from stdin (contains transcript_path)
# 2. Display cached quote (fast path)
# 3. Check rate limit - if enough time passed, spawn generator in background
```

Key logic:
- Read from single JSON cache: `~/.cache/claude-code-marvin/state.json`
  ```json
  {
    "quote": "Here I am, brain the size of a planet...",
    "generated_at": 1705412345
  }
  ```
- If no cache exists, pick random quote from **embedded fallback array**:
  ```bash
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
  ```
- Output quote with dim cyan italic ANSI styling
- Check `generated_at` timestamp
- If >3 minutes since last generation AND no lock file exists:
  - Spawn `marvin-generate.sh` in background with `nohup ... &`
  - Pass transcript_path to generator

**Composable output**: Script outputs a styled string to stdout that can be used:
- As the entire status line
- As part of an existing status line script (call this script, capture output, combine)

### 2. Create `marvin-generate.sh`
**Purpose**: Background generator using Claude Code headless

```bash
#!/bin/bash
# 1. Create lock file
# 2. Read transcript, extract last ~5 user messages
# 3. Call: claude --model haiku -p "..." with embedded Marvin prompt
# 4. Write quote + timestamp to JSON cache file
# 5. Remove lock
```

Key features:
- **Lock file**: `~/.cache/claude-code-marvin/generation.lock` - prevents concurrent generations
- **Context extraction**: Parse JSONL transcript, grep for user messages, extract text
- **Embedded prompt**: Marvin personality prompt directly in script
- **Claude Code headless**: `claude --model haiku -p "Given this conversation: ... Generate a Marvin quote"`
- **JSON output**: Write both quote and timestamp atomically to `state.json`
- **Logging**: Append to `~/.cache/claude-code-marvin/marvin.log` with timestamp for debugging
  - Simple format: `[2024-01-16 14:30:00] Generated quote: "..."` or `[...] Error: ...`
  - Uses `date` and file append (`>>`), available on all Linux/macOS

### 3. Create `install.sh`
```bash
#!/bin/bash
# Downloads repo to ~/.claude-code-marvin/
# Makes scripts executable
# Prints instructions for settings.json update
```

**Curl install command** (for README):
```bash
curl -fsSL https://raw.githubusercontent.com/USER/claude-code-marvin/main/install.sh | bash
```

### 4. Create `uninstall.sh`
```bash
#!/bin/bash
# rm -rf ~/.claude-code-marvin/
# rm -rf ~/.cache/claude-code-marvin/
# Print reminder to update settings.json
```

**Curl uninstall command** (for README):
```bash
curl -fsSL https://raw.githubusercontent.com/USER/claude-code-marvin/main/uninstall.sh | bash
```

### 5. Create `README.md`
- One-line curl install command
- One-line curl uninstall command
- Manual setup: Add to `~/.claude/settings.json`
- Configuration via environment variables
- How it works explanation

## Color Scheme

**Dim cyan italic** (`\033[2;3;36m`): Muted, robotic, slightly sad - perfectly captures Marvin's perpetually underwhelmed demeanor.

Reset code: `\033[0m`

**Display safety**: Use `printf '%s'` instead of `echo -e` to output quotes. This prevents escape sequences in the quote content (like `\n`) from being interpreted, which would break ANSI styling mid-string.

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `MARVIN_CACHE_DIR` | `~/.cache/claude-code-marvin` | Cache location |
| `MARVIN_MIN_INTERVAL` | `180` (3 min) | Seconds between generations |

## Status Line Configuration

**Option A: Standalone** - Use as your entire status line:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude-code-marvin/marvin-statusline.sh"
  }
}
```

**Option B: Composable** - Integrate with existing status line:
```bash
#!/bin/bash
# In your existing statusline-command.sh
input=$(cat)

# Your existing status line content
MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')

# Add Marvin quote (pass input JSON so it can trigger generation)
MARVIN=$("$HOME/.claude-code-marvin/marvin-statusline.sh" <<< "$input")

echo "[$MODEL] \$$COST | $MARVIN"
```

This follows the same pattern as the official git-branch example in Claude Code docs - call an external command and compose its output.

That's it - no hooks, no plugins. Just clone and configure.

## Embedded Marvin Prompt

Directly in `marvin-generate.sh`:
```
You are Marvin the Paranoid Android from Hitchhiker's Guide to the Galaxy.
You are depressed, world-weary, with a brain the size of a planet but given trivial tasks.
Generate ONE short quote (under 80 chars) about this conversation.
Be witty and darkly humorous, not mean-spirited. No quotes around the output.
```

## Error Handling

- **Status line**: If cache missing, pick random quote from embedded fallback array. Never block.
- **Generator**: If Claude Code fails, log error and silently exit (keep old quote)
- **Lock contention**: If lock exists, skip generation silently
- **Missing transcript**: Generate generic Marvin quote or use fallback
- **All errors logged**: Append to `marvin.log` for debugging

## Critical Implementation Details

1. **Status line must be fast**: Only file reads in the main path. Background spawn must be non-blocking (`nohup cmd &` with stdin/stdout redirected)

2. **Transcript parsing**: The transcript is JSONL. User messages have `"role":"user"`. Content can be string or array of content blocks.

3. **Rate limiting**: Check `generated_at` from `state.json`, compare to current time.

4. **Lock file**: Use `flock` if available, otherwise simple file existence check with cleanup on exit.

5. **Atomic JSON write**: Write to temp file, then `mv` to `state.json` to prevent partial reads.

## Verification (Local Test Loop)

Create an isolated test environment in `/tmp` to verify without affecting global settings:

```bash
# 1. Create temp test folder
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# 2. Set up project-local Claude Code settings
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/claude-code-marvin/marvin-statusline.sh"
  }
}
EOF

# 3. Create a dummy file so it looks like a project
echo "# Test Project" > README.md

# 4. Run Claude Code in this folder
cd "$TEST_DIR" && claude

# 5. Verify:
#    - Status line shows a fallback quote initially
#    - After a conversation, check ~/.cache/claude-code-marvin/state.json
#    - Wait 3+ min, have another exchange, verify new quote appears
```

**Test checklist**:
1. Fallback quote appears immediately (from embedded array)
2. After conversation + 3 min wait, new contextual quote appears
3. Check `marvin.log` for generation logs
4. Verify no errors in log
5. Test composable mode (call script from another status line script)

## Implementation Tasklist

- [x] Create `marvin-statusline.sh` - Main entry point with cached quote display and background generation trigger
- [x] Create `marvin-generate.sh` - Background generator using Claude Code headless
- [x] Create `install.sh` - Installer script for curl-based installation
- [x] Create `uninstall.sh` - Clean removal script
- [x] Create `README.md` - Documentation with install/uninstall commands and usage
- [x] Create `LICENSE` - MIT license
- [x] Per-session isolation - Derive session ID from transcript_path, create per-session cache directories
- [x] Display fix - Use printf instead of echo -e to prevent escape sequence interpretation in quotes
- [x] Quote cleanup - Remove all control characters including \r and \0-\037 range
- [x] Auto-cleanup - Opportunistic session cleanup (7 days) and log truncation (50KB)
