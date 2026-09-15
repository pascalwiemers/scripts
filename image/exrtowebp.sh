#!/usr/bin/env bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Convert ACEScg EXRs to compact, display-ready WebP images.
#
# Usage:
#   exrtowebp.sh [file.exr ...]
#   exrtowebp.sh -folder [file.exr ...]  # output to ./webp/
#
# Environment overrides:
#   WEBP_QUALITY=80 JOBS=8

# Locate the shared helper in the checkout or the Dolphin deployment.
EXR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/../lib/exr_channels.sh"
[[ -f "$EXR_CHANNELS_LIB" ]] || EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/lib/exr_channels.sh"
source "$EXR_CHANNELS_LIB" || exit 1

set -uo pipefail
shopt -s nullglob

USE_FOLDER=0
if [[ "${1:-}" == "-folder" ]]; then
    USE_FOLDER=1
    shift
fi

QUALITY="${WEBP_QUALITY:-80}"
JOBS="${JOBS:-$(nproc)}"

for value_name in QUALITY JOBS; do
    value="${!value_name}"
    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 )); then
        echo "Invalid $value_name: $value" >&2
        exit 2
    fi
done
if (( QUALITY > 100 )); then
    echo "WEBP_QUALITY must be between 1 and 100." >&2
    exit 2
fi

for dependency in oiiotool convert; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "Missing dependency: $dependency" >&2
        exit 1
    fi
done

if (( $# == 0 )); then
    FILES=(*.exr *.EXR)
else
    FILES=("$@")
fi

if (( ${#FILES[@]} == 0 )); then
    echo "No .exr files found."
    exit 0
fi

if (( USE_FOLDER == 1 )); then
    mkdir -p webp
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/exrtowebp.XXXXXX")"
trap 'rm -rf -- "$TEMP_DIR"' EXIT INT TERM

export USE_FOLDER QUALITY TEMP_DIR

# The 16-bit PNG keeps smooth semi-transparent edges between the OCIO transform
# and the final 8-bit WebP encoding. RGB stays premultiplied to match review
# applications in this pipeline.
printf '%s\0' "${FILES[@]}" | xargs -0 -r -n 1 -P "$JOBS" bash -c '
    INPUT="$1"

    if [[ ! -f "$INPUT" ]]; then
        echo "Missing: $INPUT" >&2
        exit 1
    fi
    if [[ "${INPUT,,}" != *.exr ]]; then
        echo "Skipping $INPUT (not an EXR)"
        exit 0
    fi

    STEM="$(basename "${INPUT%.*}")"
    if (( USE_FOLDER == 1 )); then
        OUTPUT="webp/${STEM}.webp"
    else
        OUTPUT="${INPUT%.*}.webp"
    fi
    CH_ARGS=$(exr_channel_args "$INPUT" keep) || exit 1
    INTERMEDIATE="$(mktemp "$TEMP_DIR/frame.XXXXXX.png")"

    echo "Converting $INPUT → $OUTPUT ..."
    if ! oiiotool "$INPUT" \
        --ch "$CH_ARGS" \
        --colorconvert "ACES - ACEScg" "Output - sRGB" \
        -d uint16 \
        -o "$INTERMEDIATE"; then
        echo "Error applying the ACEScg display transform to $INPUT" >&2
        rm -f -- "$INTERMEDIATE"
        exit 1
    fi

    if convert "$INTERMEDIATE" \
        -strip \
        -define webp:method=6 \
        -define webp:alpha-quality=100 \
        -quality "$QUALITY" \
        "$OUTPUT"; then
        echo "Done: $OUTPUT"
        rm -f -- "$INTERMEDIATE"
    else
        echo "Error encoding $INPUT" >&2
        rm -f -- "$INTERMEDIATE"
        exit 1
    fi
' _
