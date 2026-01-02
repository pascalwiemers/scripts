#!/bin/bash

# This script backs up Dolphin file manager settings from the current user's home directory.
# It backs up:
#   - ~/.config/dolphinrc (main configuration)
#   - ~/.local/share/dolphin/ (state and view properties)
#   - ~/.local/share/kxmlgui5/dolphin/ (UI layout and toolbars)
# Copies to a specified backup location inside a dated subfolder (YYMMDD).
# Uses rsync for efficient synchronization, preserving file permissions, timestamps, and handling updates.

# Default destination backup directory
DEFAULT_DEST="/mnt/r/program/dolphin/setup"

# Prompt for backup location
echo "Default backup location: $DEFAULT_DEST"
echo "Enter a different backup location or press Enter to use the default:"
read USER_DEST

# Use user input if provided, otherwise default
DEST="${USER_DEST:-$DEFAULT_DEST}"

# Create dated subfolder in YYMMDD format
DATE_FOLDER=$(date +%y%m%d)
BACKUP_DIR="$DEST/$DATE_FOLDER"

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create backup directory $BACKUP_DIR."
        exit 1
    fi
fi

# Backup dolphinrc
SOURCE_CONFIG="$HOME/.config/dolphinrc"
if [ -f "$SOURCE_CONFIG" ]; then
    BACKUP_CONFIG_DIR="$BACKUP_DIR/.config"
    mkdir -p "$BACKUP_CONFIG_DIR"
    rsync -av --progress "$SOURCE_CONFIG" "$BACKUP_CONFIG_DIR/"
    if [ $? -eq 0 ]; then
        echo "✅ Backed up dolphinrc"
    else
        echo "⚠️  Warning: Failed to backup dolphinrc"
    fi
else
    echo "⚠️  Warning: dolphinrc not found at $SOURCE_CONFIG"
fi

# Backup ~/.local/share/dolphin/
SOURCE_DOLPHIN="$HOME/.local/share/dolphin"
if [ -d "$SOURCE_DOLPHIN" ]; then
    BACKUP_DOLPHIN_DIR="$BACKUP_DIR/.local/share/dolphin"
    mkdir -p "$BACKUP_DOLPHIN_DIR"
    rsync -av --progress "$SOURCE_DOLPHIN/" "$BACKUP_DOLPHIN_DIR/"
    if [ $? -eq 0 ]; then
        echo "✅ Backed up ~/.local/share/dolphin/"
    else
        echo "⚠️  Warning: Failed to backup ~/.local/share/dolphin/"
    fi
else
    echo "⚠️  Warning: ~/.local/share/dolphin/ not found"
fi

# Backup ~/.local/share/kxmlgui5/dolphin/
SOURCE_KXMLGUI="$HOME/.local/share/kxmlgui5/dolphin"
if [ -d "$SOURCE_KXMLGUI" ]; then
    BACKUP_KXMLGUI_DIR="$BACKUP_DIR/.local/share/kxmlgui5/dolphin"
    mkdir -p "$BACKUP_KXMLGUI_DIR"
    rsync -av --progress "$SOURCE_KXMLGUI/" "$BACKUP_KXMLGUI_DIR/"
    if [ $? -eq 0 ]; then
        echo "✅ Backed up ~/.local/share/kxmlgui5/dolphin/"
    else
        echo "⚠️  Warning: Failed to backup ~/.local/share/kxmlgui5/dolphin/"
    fi
else
    echo "⚠️  Warning: ~/.local/share/kxmlgui5/dolphin/ not found"
fi

echo ""
echo "🎉 Backup completed successfully to $BACKUP_DIR."

