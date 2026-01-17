# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Paranoid Android is a status line extension that displays Marvin the Paranoid Android quotes. It uses a two-script architecture for non-blocking operation:

1. **statusline.sh** - Fast display script (called every ~300ms by Claude Code)
   - Reads cached quote from `~/.cache/claude-code-paranoid-android/sessions/<session-id>/state.json`
   - Falls back to embedded quotes array if no cache
   - Spawns generator in background if rate limit allows (3 min default)

2. **generate.sh** - Background generator
   - Extracts last 5 user messages from Claude Code's JSONL transcript
   - Calls `claude --model haiku -p "..."` to generate contextual quote
   - Writes atomically to state.json with lock file protection

Per-session isolation: Session ID derived from MD5 of `transcript_path` (12 chars), preventing race conditions across multiple Claude instances.

## Commands

```bash
# Lint all shell scripts (requires: brew install shellcheck shfmt)
./lint.sh

# Auto-fix formatting issues
./lint.sh --fix
```

## Testing

Create isolated test environment:
```bash
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/.claude"
cat > "$TEST_DIR/.claude/settings.json" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/this/repo/statusline.sh"
  }
}
EOF
echo "# Test" > "$TEST_DIR/README.md"
cd "$TEST_DIR" && claude
```

Test the statusline directly:
```bash
echo '{"transcript_path": "/tmp/test.jsonl"}' | ./statusline.sh
```

Check logs:
```bash
cat ~/.cache/claude-code-paranoid-android/sessions/*/paranoid-android.log
```

## Development Workflow

- **SPEC.md is the product spec** - Always read it before making changes
- When implementing features, add a task to the "Implementation Tasklist" at the end of SPEC.md
- Commit after completing each task (not batched)
- Update SPEC.md when architectural decisions change

## Key Implementation Details

- Status line must never block - only file reads in hot path
- Use `printf '%b%s%b\n'` for ANSI styling to prevent escape interpretation in quote content
- Atomic writes via temp file + `mv` to prevent partial reads
- Lock file (`generation.lock`) prevents concurrent generations
- Quote cleanup removes all control characters including `\r` and `\0-\037` range
