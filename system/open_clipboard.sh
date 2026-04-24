#!/bin/bash

# Function to get clipboard content (supports multiple clipboard tools)
get_clipboard() {
    if command -v wl-clipboard &> /dev/null; then
        wl-paste --no-newline
    elif command -v xclip &> /dev/null; then
        xclip -o -selection clipboard
    elif command -v xsel &> /dev/null; then
        xsel --clipboard
    else
        notify-send "Error" "No clipboard tool found. Please install xclip, wl-clipboard, or xsel."
        exit 1
    fi
}

path=$(get_clipboard | xargs)  # Get and trim clipboard content

# Function to check if any file in sequence exists
check_sequence_exists() {
    local pattern="$1"
    # Replace #### with ???? for globbing (compgen -G doesn't support [0-9] character classes)
    local glob_path="${pattern//####/????}"
    # Check if any file matches the pattern
    if compgen -G "$glob_path" > /dev/null 2>&1; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

# Function to find file manager
find_file_manager() {
    if command -v dolphin &> /dev/null; then
        echo "dolphin"
    elif command -v nemo &> /dev/null; then
        echo "nemo"
    elif command -v nautilus &> /dev/null; then
        echo "nautilus"
    elif command -v thunar &> /dev/null; then
        echo "thunar"
    else
        echo ""
    fi
}

# Check if path is an image sequence
if [[ "$path" =~ \.(#+|[0-9]{4})\.(exr|png|jpg|jpeg|tif|tiff|dpx)$ ]] && check_sequence_exists "$path"; then
    if command -v justview &> /dev/null; then
        justview "$path"  # Open image sequences with justview
    else
        notify-send "Error" "justview not found in PATH"
    fi
# Check if path exists and is a file or directory
elif [ -e "$path" ]; then
    # If it's a file and has a video extension
    if [ -f "$path" ] && [[ "$path" =~ \.(mp4|mkv|avi|mov|wmv|flv|webm)$ ]]; then
        if command -v justview &> /dev/null; then
            justview "$path"  # Open video files with justview
        else
            notify-send "Error" "justview not found in PATH"
        fi
    # If it's a directory or other file
    elif [ -d "$path" ] || [ -f "$path" ]; then
        file_manager=$(find_file_manager)
        if [ -n "$file_manager" ]; then
            $file_manager "$path"  # Open with file manager
        else
            notify-send "Error" "No file manager found."
        fi
    fi
else
    notify-send "Invalid path in clipboard: $path"
fi
