# Claude Code Paranoid Android

> "Here I am, brain the size of a planet, and you want me to display status messages."

Give your [Claude Code status line](https://docs.anthropic.com/en/docs/claude-code/settings#status-line) a personality.
<img width="1066" height="219" alt="Screenshot 2026-01-17 at 10 25 14 AM" src="https://github.com/user-attachments/assets/d321c08b-31aa-4340-a2c7-8035c1ad3767" />

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/ParthGandhi/claude-code-paranoid-android/main/install.sh | bash
```

Then add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude-code-paranoid-android/paranoid-android-statusline.sh"
  }
}
```

### Composable Usage

Already have a status line? Integrate Paranoid Android with your existing script:

```bash
#!/bin/bash
# my-statusline.sh
input=$(cat)

# Your existing status line content
MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')

# Add Paranoid Android quote
PARANOID_ANDROID=$("$HOME/.claude-code-paranoid-android/paranoid-android-statusline.sh" <<< "$input")

echo "[$MODEL] \$$COST | $PARANOID_ANDROID"
```

## Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/ParthGandhi/claude-code-paranoid-android/main/uninstall.sh | bash
```

Then remove the `statusLine` section from your `~/.claude/settings.json`.

## How It Works

1. **Status line displays cached quote** - Fast, no blocking. Falls back to embedded quotes if no cache.
2. **Background generation** - Every minute (configurable), spawns a background process to generate a new contextual quote using Claude Haiku.
3. **Context-aware** - Reads your recent conversation to generate relevant, Marvin-style commentary on your coding session.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PARANOID_ANDROID_CACHE_DIR` | `~/.cache/claude-code-paranoid-android` | Cache location |
| `PARANOID_ANDROID_MIN_INTERVAL` | `60` (1 min) | Seconds between generations |

## Debugging

Test quote generation directly with debug mode:

```bash
~/.claude-code-paranoid-android/paranoid-android-generate.sh --debug <transcript_path>
```

This outputs the full prompt, timing info, and both raw and truncated quotes.

Each Claude Code session gets its own cache directory:

```bash
# List active sessions
ls ~/.cache/claude-code-paranoid-android/sessions/

# Check logs for generation history and errors
cat ~/.cache/claude-code-paranoid-android/sessions/*/paranoid-android.log

# View cached state
cat ~/.cache/claude-code-paranoid-android/sessions/*/state.json
```

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- `jq` for JSON parsing
- macOS or Linux
