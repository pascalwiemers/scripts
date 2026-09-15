#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Convert EXR → JPG. If no inputs, process all *.exr in current directory.
# -folder → place converted JPGs into ./jpg/

# Locate the shared helper in the checkout or the Dolphin deployment.
EXR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/../lib/exr_channels.sh"
[[ -f "$EXR_CHANNELS_LIB" ]] || EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/lib/exr_channels.sh"
source "$EXR_CHANNELS_LIB" || exit 1

USE_FOLDER=0

# Parse -folder flag
if [ "$1" = "-folder" ]; then
    USE_FOLDER=1
    shift
fi

# If no input files passed, use all .exr in CWD
if [ $# -eq 0 ]; then
    set -- *.exr
fi

# If no .exr found
if [ "$1" = "*.exr" ]; then
    echo "No .exr files found."
    exit 1
fi

# Ensure output folder exists if flag is used
if [ $USE_FOLDER -eq 1 ]; then
    mkdir -p jpg
fi

# Convert in parallel
JOBS="${JOBS:-$(nproc)}"
export USE_FOLDER

printf '%s\0' "$@" | \
xargs -0 -n 1 -P "$JOBS" bash -c '
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && echo "Missing: $INPUT" && exit 1
    [[ ! "$INPUT" =~ \.exr$ ]] && echo "Skip: $INPUT" && exit 0

    OUT="${INPUT%.exr}.jpg"
    if [ "$USE_FOLDER" -eq 1 ]; then
        OUT="jpg/$(basename "$OUT")"
    fi

    CH_ARGS=$(exr_channel_args "$INPUT" drop) || exit 1
    if oiiotool "$INPUT" --ch "$CH_ARGS" --colorconvert "ACES - ACEScg" "Output - sRGB" -d uint8 -o "$OUT"; then
        echo "$INPUT → $OUT"
    else
        echo "Error on $INPUT"
        exit 1
    fi
' _

