#!/bin/bash

# --- CONFIGURATION ---
SAVE_BASE="$HOME/Videos/Recordings"
PID_FILE="/tmp/recording_ffmpeg.pid"
PATH_FILE="/tmp/recording_path.txt"

# Audio Devices
DESKTOP_AUDIO="alsa_output.pci-0000_0d_00.6.analog-stereo.monitor"
MIC_AUDIO="alsa_input.usb-ZOOM_Corporation_ZOOM_P4_Audio_000000000000-00.analog-stereo"

# --- TOGGLE LOGIC ---

if [ -f "$PID_FILE" ]; then
    # STOP RECORDING MODE
    REC_PID=$(cat "$PID_FILE")
    RAW_MKV=$(cat "$PATH_FILE")

    notify-send "Recording" "Stopping and converting for Resolve..."

    # Gracefully stop FFmpeg
    kill -INT "$REC_PID"

    # Wait for FFmpeg to finish writing the file
    while kill -0 "$REC_PID" 2>/dev/null; do sleep 0.5; done

    # Define Resolve-compatible output (.mov with PCM audio)
    FINAL_MOV="${RAW_MKV%.mkv}.mov"

    # Fast remux to MOV (Copy video, convert audio to PCM)
    ffmpeg -i "$RAW_MKV" -c:v copy -c:a pcm_s16le -map 0 "$FINAL_MOV" -y

    # Cleanup
    rm "$PID_FILE" "$PATH_FILE"
    notify-send "Recording Saved" "Ready for Resolve: $(basename "$FINAL_MOV")"

else
    # START RECORDING MODE
    DATE=$(date +%Y-%m-%d)
    TIME=$(date +%H-%M-%S)
    mkdir -p "$SAVE_BASE/$DATE"

    FILENAME="$SAVE_BASE/$DATE/recording_$TIME.mkv"
    echo "$FILENAME" > "$PATH_FILE"

    notify-send "Recording" "Started: Screen + Dual Audio"

    # Detect primary screen position dynamically
    PRIMARY_INFO=$(xrandr --query | grep -E "connected.*primary" | grep -oE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+")
    if [ -z "$PRIMARY_INFO" ]; then
        notify-send "Recording Error" "Could not detect primary screen"
        exit 1
    fi
    PRIMARY_OFFSET=$(echo "$PRIMARY_INFO" | sed 's/.*+\([0-9]\+\)+\([0-9]\+\).*/\1,\2/')

    # Start FFmpeg in background
    # -r 30 ensures Constant Frame Rate for Resolve
    # Captures only primary screen (4K) at detected position
    ffmpeg -f x11grab -video_size 3840x2160 -framerate 30 -i :0.0+$PRIMARY_OFFSET \
    -f pulse -i "$DESKTOP_AUDIO" \
    -f pulse -i "$MIC_AUDIO" \
    -c:v libx264 -preset ultrafast -crf 18 -r 30 \
    -c:a flac -map 0:v -map 1:a -map 2:a \
    "$FILENAME" > /dev/null 2>&1 &

    # Save PID
    echo $! > "$PID_FILE"
fi
