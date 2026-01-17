#!/bin/bash
# uninstall.sh - Uninstaller for Claude Code Paranoid Android status line
# Usage: curl -fsSL https://raw.githubusercontent.com/ParthGandhi/claude-code-paranoid-android/main/uninstall.sh | bash

set -e

INSTALL_DIR="$HOME/.claude-code-paranoid-android"
CACHE_DIR="$HOME/.cache/claude-code-paranoid-android"

echo "Uninstalling Claude Code Paranoid Android..."
echo ""

# Remove installation directory
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
else
    echo "Installation directory not found: $INSTALL_DIR"
fi

# Remove cache directory
if [[ -d "$CACHE_DIR" ]]; then
    rm -rf "$CACHE_DIR"
    echo "Removed $CACHE_DIR"
else
    echo "Cache directory not found: $CACHE_DIR"
fi

echo ""
echo "Uninstallation complete!"
echo ""
echo "Don't forget to remove the statusLine configuration from your ~/.claude/settings.json"
echo ""
echo "\"I'd say I'll miss you, but that would be a lie. I don't miss anything.\""
