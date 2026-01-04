#!/bin/bash
#
# record_toggle.sh - Toggle screen recording with dual audio (desktop + microphone)
#
# Description:
#   This script provides a simple toggle mechanism for recording your screen with
#   simultaneous desktop audio and microphone input. On first run, it starts recording.
#   On second run, it stops the recording, converts it to Resolve-compatible format,
#   and saves it with organized filenames.
#
# Features:
#   - Records primary 4K screen at 30fps
#   - Captures desktop audio (stereo) and microphone (mono) as separate tracks
#   - Automatically detects primary screen position (works with multi-monitor setups)
#   - High-quality audio: 48kHz sample rate, FLAC lossless encoding
#   - Optional voice enhancement processing
#   - Converts recordings to Resolve-compatible .mov format on stop
#
# Usage:
#   ./record_toggle.sh
#   Run once to start recording, run again to stop and save.
#
# Configuration:
#   Edit the variables in the CONFIGURATION section to customize:
#   - SAVE_BASE: Where recordings are saved
#   - DESKTOP_AUDIO/MIC_AUDIO: PulseAudio device names (use 'pactl list sources/sinks' to find)
#   - ENABLE_VOICE_ENHANCEMENT: Enable/disable voice processing filters
#
# Requirements:
#   - ffmpeg
#   - xrandr (for screen detection)
#   - PulseAudio (for audio capture)
#   - notify-send (for notifications)
#
# Output:
#   - Raw recording: ~/Videos/Recordings/YYYY-MM-DD/recording_HH-MM-SS.mkv
#   - Final output: ~/Videos/Recordings/YYYY-MM-DD/recording_HH-MM-SS.mov (Resolve-compatible)

# --- CONFIGURATION ---
SAVE_BASE="$HOME/Videos/Recordings"
PID_FILE="/tmp/recording_ffmpeg.pid"
PATH_FILE="/tmp/recording_path.txt"

# Audio Devices (PulseAudio)
# To find your device names, run:
#   Desktop audio: pactl list sinks | grep -A 10 "Name:"
#   Microphone:    pactl list sources | grep -A 10 "Name:"
DESKTOP_AUDIO="alsa_output.pci-0000_0d_00.6.analog-stereo.monitor"
MIC_AUDIO="alsa_input.usb-ZOOM_Corporation_ZOOM_P4_Audio_000000000000-00.analog-stereo"

# Voice Enhancement Settings (for male voice)
# Set to "true" to enable: highpass filter, EQ boost, and compression
# Set to "false" for raw mic audio (mono output)
ENABLE_VOICE_ENHANCEMENT=false

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

    # Detect primary screen position dynamically (supports multi-monitor setups)
    # Extracts resolution and position offset (x,y) from xrandr output
    PRIMARY_INFO=$(xrandr --query | grep -E "connected.*primary" | grep -oE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+")
    if [ -z "$PRIMARY_INFO" ]; then
        notify-send "Recording Error" "Could not detect primary screen"
        exit 1
    fi
    # Extract x,y offset (e.g., "+0+1440" becomes "0,1440")
    PRIMARY_OFFSET=$(echo "$PRIMARY_INFO" | sed 's/.*+\([0-9]\+\)+\([0-9]\+\).*/\1,\2/')

    # Create error log file
    ERROR_LOG="/tmp/recording_ffmpeg_error.log"

    # Build mic audio filter chain
    # Extract mono channel (mic is mono, but PulseAudio may provide as stereo)
    if [ "$ENABLE_VOICE_ENHANCEMENT" = "true" ]; then
        # Enhanced: extract mono, apply enhancements, keep as mono
        MIC_FILTER="[2:a]channelsplit=channel_layout=mono[mic_mono],[mic_mono]highpass=f=85,equalizer=f=3000:t=q:w=2:g=3,compand=attacks=0.3:decays=0.8:points=-80/-80|-60/-60|-40/-20|-20/-5|0/0[mic_processed]"
        MIC_OUTPUT="mic_processed"
    else
        # Simple: extract mono channel, keep as mono
        MIC_FILTER="[2:a]channelsplit=channel_layout=mono[mic_mono]"
        MIC_OUTPUT="mic_mono"
    fi

    # Start FFmpeg in background
    # Video: 4K (3840x2160) at 30fps, constant frame rate for Resolve compatibility
    # Audio: 
    #   - Microphone: Mono channel extracted, optionally enhanced, resampled to 48kHz
    #   - Desktop: Stereo, resampled to 48kHz
    #   - Both encoded with FLAC lossless compression at maximum quality
    # Output tracks: Video, Mic (first), Desktop (second)
    ffmpeg -f x11grab -video_size 3840x2160 -framerate 30 -i :0.0+$PRIMARY_OFFSET \
    -f pulse -i "$DESKTOP_AUDIO" \
    -f pulse -i "$MIC_AUDIO" \
    -filter_complex "$MIC_FILTER;[$MIC_OUTPUT]aresample=48000[mic_48k];[1:a]aresample=48000[desktop_48k]" \
    -c:v libx264 -preset ultrafast -crf 18 -r 30 \
    -c:a flac -compression_level 12 \
    -map 0:v -map "[mic_48k]" -map "[desktop_48k]" \
    "$FILENAME" > "$ERROR_LOG" 2>&1 &

    # Save PID
    echo $! > "$PID_FILE"
fi
