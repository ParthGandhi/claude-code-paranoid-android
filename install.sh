#!/bin/bash
# install.sh - Installer for Claude Code Marvin status line
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/claude-code-marvin/main/install.sh | bash

set -e

INSTALL_DIR="$HOME/.claude-code-marvin"
REPO_URL="https://github.com/USER/claude-code-marvin"

echo "Installing Claude Code Marvin..."
echo ""

# Check for required dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is required but not installed."
        exit 1
    fi
}

check_dependency "git"
check_dependency "jq"
check_dependency "claude"

# Remove existing installation if present
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Removing existing installation..."
    rm -rf "$INSTALL_DIR"
fi

# Clone the repository
echo "Downloading to $INSTALL_DIR..."
git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
    echo "Error: Failed to clone repository"
    echo "You may need to update the REPO_URL in the install script"
    exit 1
}

# Make scripts executable
chmod +x "$INSTALL_DIR/marvin-statusline.sh"
chmod +x "$INSTALL_DIR/marvin-generate.sh"

# Create cache directory
mkdir -p "$HOME/.cache/claude-code-marvin"

echo ""
echo "Installation complete!"
echo ""
echo "To enable Marvin quotes, add this to your ~/.claude/settings.json:"
echo ""
echo '  {'
echo '    "statusLine": {'
echo '      "type": "command",'
echo '      "command": "bash ~/.claude-code-marvin/marvin-statusline.sh"'
echo '    }'
echo '  }'
echo ""
echo "Or if you have an existing status line, see the README for composable usage."
echo ""
echo '"Here I am, brain the size of a planet, and you want me to display status messages."'
