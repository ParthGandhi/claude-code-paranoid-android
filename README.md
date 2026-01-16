# Claude Code Marvin

> "Here I am, brain the size of a planet, and you want me to display status messages."

A Claude Code status line extension that displays depressed, witty Marvin the Paranoid Android quotes based on your recent conversation, generated using Claude Haiku.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/USER/claude-code-marvin/main/install.sh | bash
```

Then add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude-code-marvin/marvin-statusline.sh"
  }
}
```

## Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/USER/claude-code-marvin/main/uninstall.sh | bash
```

Then remove the `statusLine` section from your `~/.claude/settings.json`.

## How It Works

1. **Status line displays cached quote** - Fast, no blocking. Falls back to embedded quotes if no cache.
2. **Background generation** - Every 3 minutes (configurable), spawns a background process to generate a new contextual quote using Claude Haiku.
3. **Context-aware** - Reads your recent conversation to generate relevant, Marvin-style commentary on your coding session.

## Configuration

Environment variables to customize behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `MARVIN_CACHE_DIR` | `~/.cache/claude-code-marvin` | Cache location |
| `MARVIN_MIN_INTERVAL` | `180` (3 min) | Seconds between generations |

## Composable Usage

Integrate with an existing status line script:

```bash
#!/bin/bash
# my-statusline.sh
input=$(cat)

# Your existing status line content
MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')

# Add Marvin quote
MARVIN=$("$HOME/.claude-code-marvin/marvin-statusline.sh" <<< "$input")

echo "[$MODEL] \$$COST | $MARVIN"
```

## Debugging

Check the log file for generation history and errors:

```bash
cat ~/.cache/claude-code-marvin/marvin.log
```

View current cached state:

```bash
cat ~/.cache/claude-code-marvin/state.json
```

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- `jq` for JSON parsing
- `git` for installation

## License

MIT
