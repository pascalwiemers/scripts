#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Converts EXR → TIFF using oiiotool
# Usage:
#   ./convert_exr_to_tiff.sh
#   ./convert_exr_to_tiff.sh file.exr
#   ./convert_exr_to_tiff.sh *.exr
#   ./convert_exr_to_tiff.sh -folder  (outputs into ./tiff/)

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

# Make folder if requested
if [ $USE_FOLDER -eq 1 ]; then
    mkdir -p tiff
fi

# Convert in parallel
JOBS="${JOBS:-$(nproc)}"
export USE_FOLDER

printf '%s\0' "${FILES[@]}" | \
xargs -0 -n 1 -P "$JOBS" bash -c '
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && echo "Skipping '\''$INPUT'\'' (not a file)" && exit 0
    [[ ! "$INPUT" =~ \.exr$ ]] && echo "Skipping '\''$INPUT'\'' (not .exr)" && exit 0

    OUTPUT="${INPUT%.exr}.tiff"

    if [ "$USE_FOLDER" -eq 1 ]; then
        OUTPUT="tiff/$(basename "$OUTPUT")"
    fi

    echo "Converting $INPUT → $OUTPUT ..."
    if oiiotool "$INPUT" --colorconvert "role_scene_linear" "out_srgb" -o "$OUTPUT"; then
        echo "✅ $INPUT"
    else
        echo "❌ Error converting $INPUT"
    fi
' _

