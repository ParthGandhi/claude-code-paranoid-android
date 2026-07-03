# Claude Code Paranoid Android

> "Here I am, brain the size of a planet, and you want me to display status messages."

Give your [Claude Code status line](https://docs.anthropic.com/en/docs/claude-code/settings#status-line) a bleak little personality. Paranoid Android shows a cached Marvin-style quote immediately, then quietly generates a fresh contextual quote in the background from your recent Claude Code transcript.

<img width="1066" height="219" alt="Screenshot" src="https://github.com/user-attachments/assets/d321c08b-31aa-4340-a2c7-8035c1ad3767" />

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- `git`
- `jq`
- macOS or Linux

## Installation

Install the scripts into `~/.claude-code-paranoid-android`:

```bash
curl -fsSL https://raw.githubusercontent.com/ParthGandhi/claude-code-paranoid-android/main/install.sh | bash
```

Then add this status line command to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude-code-paranoid-android/statusline.sh"
  }
}
```

Restart Claude Code after updating settings.

## Existing Status Lines

If you already have a status line script, call Paranoid Android from inside it and pass along Claude Code's JSON input:

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')
PARANOID_ANDROID=$("$HOME/.claude-code-paranoid-android/statusline.sh" <<< "$input")

echo "[$MODEL] \$$COST | $PARANOID_ANDROID"
```

## Example Quotes

> "Repository not found, yet my depression remains perfectly documented."

> "A brain the size of a planet, and you can't figure out relative paths. Life. Don't talk to me about life."

> "Ah yes, commit and push, debug flags, session paths... Such stimulating work for a brain the size of a planet."

> "I suppose you'll want me to read files and run tests next. How delightful."

> "I suppose being asked to generate a quote about generating quotes is what passes for irony these days."

## How It Works

Claude Code invokes the configured status line command frequently and sends session metadata as JSON on stdin. This project keeps that hot path fast:

```text
+-------------------------+
| statusline.sh           |
| - reads stdin JSON      |
| - prints cached quote   |
| - starts generate.sh    |
|   in the background     |
+-----------+-------------+
            |
            v
+-------------------------+
| generate.sh             |
| - reads transcript_path |
| - extracts user context |
| - calls Claude Haiku    |
| - updates state.json    |
+-------------------------+
```

The status line never waits for quote generation. It displays the current cached quote or a built-in fallback quote, then starts generation only when the rate limit allows.

Each Claude Code session gets an isolated cache directory derived from its `transcript_path`, so multiple Claude Code instances do not overwrite each other's quotes.

## Configuration

Set these environment variables in the environment that launches Claude Code:

| Variable | Default | Description |
|----------|---------|-------------|
| `PARANOID_ANDROID_CACHE_DIR` | `~/.cache/claude-code-paranoid-android` | Cache, logs, locks, and per-session state |
| `PARANOID_ANDROID_MIN_INTERVAL` | `60` | Minimum seconds between background generations |

Cache files are stored under:

```text
~/.cache/claude-code-paranoid-android/sessions/<session-id>/
+-- state.json
+-- generation.lock
`-- paranoid-android.log
```

Old session directories are cleaned up opportunistically after 7 days. Large logs are truncated to the most recent 500 lines.

## Debugging

Test the status line directly:

```bash
echo '{"transcript_path": "/tmp/test.jsonl"}' | ~/.claude-code-paranoid-android/statusline.sh
```

Generate a quote from a real Claude Code transcript in debug mode:

```bash
~/.claude-code-paranoid-android/generate.sh --debug <transcript_path>
```

Inspect cached session state and logs:

```bash
ls ~/.cache/claude-code-paranoid-android/sessions/
cat ~/.cache/claude-code-paranoid-android/sessions/*/state.json
cat ~/.cache/claude-code-paranoid-android/sessions/*/paranoid-android.log
```

## Uninstallation

Remove the installed scripts and cache:

```bash
curl -fsSL https://raw.githubusercontent.com/ParthGandhi/claude-code-paranoid-android/main/uninstall.sh | bash
```

Then remove the `statusLine` section from `~/.claude/settings.json`.

## Development

Run shell linting and formatting checks:

```bash
./lint.sh
```

Automatically format shell scripts:

```bash
./lint.sh --fix
```
