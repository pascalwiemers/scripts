#!/bin/bash

# This script deploys/restores the latest Dolphin file manager settings backup to the current machine.
# It finds the latest backup (dated folder in YYMMDD format) and restores:
#   - ~/.config/dolphinrc (main configuration)
#   - ~/.local/share/dolphin/ (state and view properties)
#   - ~/.local/share/kxmlgui5/dolphin/ (UI layout and toolbars)
# Useful for replicating Dolphin settings across multiple machines.
# Uses rsync for efficient synchronization, preserving file permissions, timestamps, and handling updates.

# Default source backup directory
DEFAULT_SOURCE="/mnt/r/program/dolphin/setup"

# Prompt for backup location
echo "Default backup location: $DEFAULT_SOURCE"
echo "Enter a different backup location or press Enter to use the default:"
read USER_SOURCE

# Use user input if provided, otherwise default
SOURCE="${USER_SOURCE:-$DEFAULT_SOURCE}"

# Find the latest dated folder (assuming YYMMDD format)
LATEST=$(ls -d "$SOURCE"/[0-9][0-9][0-9][0-9][0-9][0-9] 2>/dev/null | sort -r | head -n 1)

if [ -z "$LATEST" ]; then
    echo "Error: No backup folders found in $SOURCE."
    exit 1
fi

echo "Deploying from: $LATEST"
echo ""

# Restore dolphinrc
BACKUP_CONFIG="$LATEST/.config/dolphinrc"
if [ -f "$BACKUP_CONFIG" ]; then
    mkdir -p "$HOME/.config"
    rsync -av --progress "$BACKUP_CONFIG" "$HOME/.config/"
    if [ $? -eq 0 ]; then
        echo "✅ Restored dolphinrc"
    else
        echo "⚠️  Warning: Failed to restore dolphinrc"
    fi
else
    echo "⚠️  Warning: dolphinrc backup not found in $LATEST"
fi

# Restore ~/.local/share/dolphin/
BACKUP_DOLPHIN="$LATEST/.local/share/dolphin"
if [ -d "$BACKUP_DOLPHIN" ]; then
    mkdir -p "$HOME/.local/share/dolphin"
    rsync -av --progress "$BACKUP_DOLPHIN/" "$HOME/.local/share/dolphin/"
    if [ $? -eq 0 ]; then
        echo "✅ Restored ~/.local/share/dolphin/"
    else
        echo "⚠️  Warning: Failed to restore ~/.local/share/dolphin/"
    fi
else
    echo "⚠️  Warning: ~/.local/share/dolphin/ backup not found in $LATEST"
fi

# Restore ~/.local/share/kxmlgui5/dolphin/
BACKUP_KXMLGUI="$LATEST/.local/share/kxmlgui5/dolphin"
if [ -d "$BACKUP_KXMLGUI" ]; then
    mkdir -p "$HOME/.local/share/kxmlgui5/dolphin"
    rsync -av --progress "$BACKUP_KXMLGUI/" "$HOME/.local/share/kxmlgui5/dolphin/"
    if [ $? -eq 0 ]; then
        echo "✅ Restored ~/.local/share/kxmlgui5/dolphin/"
    else
        echo "⚠️  Warning: Failed to restore ~/.local/share/kxmlgui5/dolphin/"
    fi
else
    echo "⚠️  Warning: ~/.local/share/kxmlgui5/dolphin/ backup not found in $LATEST"
fi

echo ""
echo "🎉 Deployment completed successfully from $LATEST."
echo "⚠️  Note: You may need to restart Dolphin for changes to take effect."

