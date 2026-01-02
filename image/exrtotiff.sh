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

for INPUT in "${FILES[@]}"; do
    [[ ! -f "$INPUT" ]] && echo "Skipping '$INPUT' (not a file)" && continue
    [[ ! "$INPUT" =~ \.exr$ ]] && echo "Skipping '$INPUT' (not .exr)" && continue

    OUTPUT="${INPUT%.exr}.tiff"

    if [ $USE_FOLDER -eq 1 ]; then
        OUTPUT="tiff/$(basename "$OUTPUT")"
    fi

    echo "Converting '$INPUT' → '$OUTPUT' ..."
    oiiotool "$INPUT" --colorconvert "role_scene_linear" "out_srgb" -o "$OUTPUT"

    if [ $? -eq 0 ]; then
        echo "✅ $INPUT"
    else
        echo "❌ Error converting '$INPUT'"
    fi
done

