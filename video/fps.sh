#!/bin/bash
#
# fps.sh - Set global FPS value for all video conversion scripts
#
# Description:
#   This script sets a global FPS value that will be used by all video
#   conversion scripts that take image sequences as input (pngtomp4.sh,
#   exrtomp4.sh, exrtomp4_dailies.sh, exrtoprores422.sh, exrtoprores444.sh)
#
# Usage:
#   ./fps.sh <fps_value>
#   Example: ./fps.sh 24
#   Example: ./fps.sh 30
#
#   To view current FPS: ./fps.sh
#

CONFIG_FILE="$HOME/.video_fps_config"
DEFAULT_FPS=25

# If no argument provided, show current FPS
if [ $# -eq 0 ]; then
    if [ -f "$CONFIG_FILE" ]; then
        current_fps=$(cat "$CONFIG_FILE" 2>/dev/null | grep -E '^[0-9]+(\.[0-9]+)?$' | head -n1)
        if [ -n "$current_fps" ]; then
            echo "Current global FPS: $current_fps"
        else
            echo "Config file exists but contains invalid value. Default FPS: $DEFAULT_FPS"
        fi
    else
        echo "No FPS configured. Default FPS: $DEFAULT_FPS"
        echo "Use: $0 <fps_value> to set a global FPS"
    fi
    exit 0
fi

# Validate FPS value
fps_value="$1"
if ! [[ "$fps_value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ "$fps_value" = "0" ] || [ "$fps_value" = "0.0" ]; then
    echo "Error: Invalid FPS value. Must be a positive number."
    echo "Example: $0 24"
    echo "Example: $0 29.97"
    exit 1
fi

# Write FPS to config file
echo "$fps_value" > "$CONFIG_FILE"
echo "Global FPS set to: $fps_value"
echo "This will be used by all video conversion scripts (unless overridden with -fps flag)"

