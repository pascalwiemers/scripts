#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Convert EXR → JPG. If no inputs, process all *.exr in current directory.
# -folder → place converted JPGs into ./jpg/

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

    if oiiotool "$INPUT" --colorconvert "role_scene_linear" "out_srgb" -o "$OUT"; then
        echo "$INPUT → $OUT"
    else
        echo "Error on $INPUT"
        exit 1
    fi
' _

