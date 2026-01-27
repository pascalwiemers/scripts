#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu

# Logging for debugging
LOGfile="/tmp/vid_cut_debug.log"
echo "--- $(date) ---" >> "$LOGfile"
echo "Args: $@" >> "$LOGfile"

# Open LosslessCut with the provided files
if [ $# -eq 0 ]; then
    echo "No arguments provided." >> "$LOGfile"
    exit 0
fi

# Use --appimage-extract-and-run to bypass FUSE issues
# Use --no-sandbox for Electron compatibility
# We must pass the arguments after the flags
/usr/local/bin/losslesscut --appimage-extract-and-run --no-sandbox "$@" >> "$LOGfile" 2>&1

EXIT_CODE=$?
echo "Exit code: $EXIT_CODE" >> "$LOGfile"
