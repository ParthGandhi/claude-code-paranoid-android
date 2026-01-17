# Claude Code Paranoid Android

> "Here I am, brain the size of a planet, and you want me to display status messages."

Give your [Claude Code status line](https://docs.anthropic.com/en/docs/claude-code/settings#status-line) a personality.
<img width="1066" height="219" alt="Screenshot" src="https://github.com/user-attachments/assets/d321c08b-31aa-4340-a2c7-8035c1ad3767" />

### Example Quotes

> "I've calculated the probability of `private: true` improving your life. The result is classified as a decimal number."

> "Repository not found, yet my depression remains perfectly documented."

> "A brain the size of a planet, and you can't figure out relative paths. Life. Don't talk to me about life."

> "Ah yes, commit and push, debug flags, session paths... Such stimulating work for a brain the size of a planet."

> "I suppose you'll want me to read files and run tests next. How delightful."

> "I suppose being asked to generate a quote about generating quotes is what passes for irony these days."

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

The status line receives JSON with `transcript_path` every ~300ms. We use this to:
1. Always display the cached quote (fast, non-blocking)
2. Opportunistically spawn the generator in background when rate limit allows

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
