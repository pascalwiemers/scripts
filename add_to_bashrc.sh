#!/bin/bash

# Get the directory where this script is located
# Or should it be the current working directory? 
# Usually, users want to add the directory they are currently in or the script's directory.
# Let's use the current working directory as it's more flexible for "adding the path".

CURRENT_DIR=$(pwd)

# Replace the actual home path with $HOME as requested
DIR_WITH_HOME_VAR=$(echo "$CURRENT_DIR" | sed "s|^$HOME|\$HOME|")

# Find all subdirectories (including the current directory itself)
# Using find to get all directories recursively
ALL_DIRS=$(find "$CURRENT_DIR" -type d | sort)

# Build PATH string with all directories using $HOME notation
BASHRC="$HOME/.bashrc"
PATH_ADDITIONS=""

while IFS= read -r dir; do
    # Replace home path with $HOME
    dir_with_home=$(echo "$dir" | sed "s|^$HOME|\$HOME|")
    # Add to PATH additions
    if [ -z "$PATH_ADDITIONS" ]; then
        PATH_ADDITIONS="$dir_with_home"
    else
        PATH_ADDITIONS="$PATH_ADDITIONS:$dir_with_home"
    fi
done <<< "$ALL_DIRS"

# Create the PATH export line
PATH_LINE="export PATH=\"\$PATH:$PATH_ADDITIONS\""

# Check if any of these paths already exist in .bashrc
# We'll check if the main directory is already there as a simple check
if grep -q "$DIR_WITH_HOME_VAR" "$BASHRC" 2>/dev/null; then
    echo "Warning: Some paths from $DIR_WITH_HOME_VAR may already be in $BASHRC"
    echo "Checking for exact match..."
    if grep -Fxq "$PATH_LINE" "$BASHRC"; then
        echo "The exact PATH line is already in $BASHRC"
        exit 0
    fi
fi

# Append to .bashrc
echo -e "\n# Added by add_to_bashrc.sh (includes all subdirectories)\n$PATH_LINE" >> "$BASHRC"
echo "Added $DIR_WITH_HOME_VAR and all subdirectories to $BASHRC"
echo "Total directories added: $(echo "$ALL_DIRS" | wc -l)"
echo "Run 'source ~/.bashrc' to update your current shell."

