#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Converts EXR → PNG using oiiotool
# Usage:
#   ./convert_exr_to_png.sh
#   ./convert_exr_to_png.sh file.exr
#   ./convert_exr_to_png.sh *.exr
#   ./convert_exr_to_png.sh -folder   (outputs into ./png/)

# Locate the shared helper in the checkout or the Dolphin deployment.
EXR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/../lib/exr_channels.sh"
[[ -f "$EXR_CHANNELS_LIB" ]] || EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/lib/exr_channels.sh"
source "$EXR_CHANNELS_LIB" || exit 1

shopt -s nullglob

USE_FOLDER=0

# Parse -folder flag
if [[ "$1" == "-folder" ]]; then
    USE_FOLDER=1
    shift
fi

# Determine input files
if [ $# -eq 0 ]; then
    FILES=(*.exr)
    if [ ${#FILES[@]} -eq 0 ]; then
        echo "No .exr files found in current directory."
        exit 0
    fi
else
    FILES=("$@")
fi

# Make output folder if requested
if [ $USE_FOLDER -eq 1 ]; then
    mkdir -p png
fi

# Convert in parallel
JOBS="${JOBS:-$(nproc)}"
export USE_FOLDER

printf '%s\0' "${FILES[@]}" | \
xargs -0 -n 1 -P "$JOBS" bash -c '
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && echo "Skipping '\''$INPUT'\'' (not a file)" && exit 0
    [[ ! "$INPUT" =~ \.exr$ ]] && echo "Skipping '\''$INPUT'\'' (not an .exr file)" && exit 0

    OUTPUT="${INPUT%.exr}.png"
    if [ "$USE_FOLDER" -eq 1 ]; then
        OUTPUT="png/$(basename "$OUTPUT")"
    fi

    CH_ARGS=$(exr_channel_args "$INPUT" keep) || exit 1

    echo "Converting $INPUT → $OUTPUT ..."
    if oiiotool "$INPUT" --ch "$CH_ARGS" --colorconvert "ACES - ACEScg" "Output - sRGB" -d uint16 -o "$OUTPUT"; then
        echo "✅ $INPUT"
    else
        echo "❌ Error converting $INPUT"
        exit 1
    fi
' _
