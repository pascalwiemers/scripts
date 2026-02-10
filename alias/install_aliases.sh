#!/bin/bash
# Script to add aliases reference to .bashrc

# Get the directory where this script is located (works on any machine)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_FILE="$SCRIPT_DIR/aliases.sh"
BASHRC_FILE="$HOME/.bashrc"
SOURCE_LINE="source \"$ALIASES_FILE\""
MARKER="# Custom aliases from scripts repo"

# Check if aliases.sh exists
if [[ ! -f "$ALIASES_FILE" ]]; then
    echo "Error: aliases.sh not found at $ALIASES_FILE"
    exit 1
fi

# Check if already sourced (look for the marker comment)
if grep -qF "$MARKER" "$BASHRC_FILE" 2>/dev/null; then
    echo "Aliases are already sourced in .bashrc"
    echo "Current path: $(grep -A1 "$MARKER" "$BASHRC_FILE" | tail -1)"
    exit 0
fi

# Add a newline and the source line to .bashrc
echo "" >> "$BASHRC_FILE"
echo "$MARKER" >> "$BASHRC_FILE"
echo "$SOURCE_LINE" >> "$BASHRC_FILE"

echo "Added aliases reference to .bashrc"
echo "Aliases file: $ALIASES_FILE"
echo "Run 'source ~/.bashrc' or open a new terminal to apply changes"
