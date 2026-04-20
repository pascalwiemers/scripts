#!/bin/bash
#
# record_toggle_desktop.sh - Toggle screen recording with desktop audio only (no microphone)
#
# Description:
#   Same as record_toggle.sh but captures only desktop audio, no microphone.
#
# Usage:
#   ./record_toggle_desktop.sh
#   Run once to start recording, run again to stop and save.
#
# Output:
#   - Raw recording: ~/Videos/Recordings/YYYY-MM-DD/recording_HH-MM-SS.mkv
#   - Final output: ~/Videos/Recordings/YYYY-MM-DD/recording_HH-MM-SS.mov (Resolve-compatible)

# --- CONFIGURATION ---
SAVE_BASE="$HOME/Videos/Recordings"
PID_FILE="/tmp/recording_desktop_ffmpeg.pid"
PATH_FILE="/tmp/recording_desktop_path.txt"

# Audio Device (PulseAudio)
DESKTOP_AUDIO="alsa_output.pci-0000_0d_00.6.analog-stereo.monitor"

# --- TOGGLE LOGIC ---

if [ -f "$PID_FILE" ]; then
    # STOP RECORDING MODE
    REC_PID=$(cat "$PID_FILE")
    RAW_MKV=$(cat "$PATH_FILE")

    notify-send "Recording" "Stopping and converting for Resolve..."

    kill -INT "$REC_PID"
    while kill -0 "$REC_PID" 2>/dev/null; do sleep 0.5; done

    FINAL_MOV="${RAW_MKV%.mkv}.mov"

    ffmpeg -i "$RAW_MKV" -c:v copy -c:a pcm_s16le -map 0 "$FINAL_MOV" -y

    rm "$PID_FILE" "$PATH_FILE"
    notify-send "Recording Saved" "Ready for Resolve: $(basename "$FINAL_MOV")"

else
    # START RECORDING MODE
    DATE=$(date +%Y-%m-%d)
    TIME=$(date +%H-%M-%S)
    mkdir -p "$SAVE_BASE/$DATE"

    FILENAME="$SAVE_BASE/$DATE/recording_$TIME.mkv"
    echo "$FILENAME" > "$PATH_FILE"

    notify-send "Recording" "Started: Screen + Desktop Audio"

    PRIMARY_INFO=$(xrandr --query | grep -E "connected.*primary" | grep -oE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+")
    if [ -z "$PRIMARY_INFO" ]; then
        notify-send "Recording Error" "Could not detect primary screen"
        exit 1
    fi
    PRIMARY_OFFSET=$(echo "$PRIMARY_INFO" | sed 's/.*+\([0-9]\+\)+\([0-9]\+\).*/\1,\2/')

    ERROR_LOG="/tmp/recording_desktop_ffmpeg_error.log"

    ffmpeg -f x11grab -video_size 3840x2160 -framerate 30 -i :0.0+$PRIMARY_OFFSET \
    -f pulse -i "$DESKTOP_AUDIO" \
    -filter_complex "[1:a]aresample=48000[desktop_48k]" \
    -c:v libx264 -preset ultrafast -crf 18 -r 30 \
    -c:a flac -compression_level 12 \
    -map 0:v -map "[desktop_48k]" \
    "$FILENAME" > "$ERROR_LOG" 2>&1 &

    echo $! > "$PID_FILE"
fi
