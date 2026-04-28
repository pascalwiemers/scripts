#!/usr/bin/env bash
#
# offset_frames.sh
# Detect most negative frame in EXR sequence, shift entire sequence so
# lowest frame becomes START_FRAME.
#
# Usage:
#   ./offset_frames.sh [directory] [start_frame]
#
# Defaults:
#   directory   = current working directory
#   start_frame = 1
#
# Filename pattern: <name>.<frame>.exr   (frame may be negative: -0049)

set -euo pipefail

DIR="${1:-.}"
START_FRAME="${2:-1}"
OUT_PAD=4

cd "$DIR"

shopt -s nullglob
files=( *.exr )
if (( ${#files[@]} == 0 )); then
    echo "No .exr files found in $DIR"
    exit 1
fi

# Capture original token (sign + digits) directly — no reconstruction.
declare -a frames
declare -A file_to_frame
declare -A file_to_token

frame_re='\.(-?[0-9]+)\.exr$'

for f in "${files[@]}"; do
    if [[ "$f" =~ $frame_re ]]; then
        raw="${BASH_REMATCH[1]}"
        if [[ "$raw" == -* ]]; then
            num=$((-1 * 10#${raw#-}))
        else
            num=$((10#$raw))
        fi
        frames+=( "$num" )
        file_to_frame["$f"]="$num"
        file_to_token["$f"]="$raw"
    else
        echo "WARN: skipping unrecognised filename: $f"
    fi
done

if (( ${#frames[@]} == 0 )); then
    echo "No files matched frame pattern."
    exit 1
fi

min=${frames[0]}
max=${frames[0]}
for n in "${frames[@]}"; do
    (( n < min )) && min=$n
    (( n > max )) && max=$n
done

OFFSET=$(( START_FRAME - min ))

echo "------------------------------------------------------------"
echo "Directory   : $DIR"
echo "Files       : ${#files[@]}"
echo "Frame range : $min -> $max"
echo "Target start: $START_FRAME"
echo "Offset      : $OFFSET  (ADDED to every frame number)"
echo "New range   : $((min + OFFSET)) -> $((max + OFFSET))"
echo "------------------------------------------------------------"

if (( OFFSET == 0 )); then
    echo "Already aligned. Nothing to do."
    exit 0
fi

if [[ -z "${OFFSET_FRAMES_YES:-}" ]]; then
    read -r -p "Proceed with rename? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

TMP_PREFIX=".__renaming__"

# Phase 1: stage with temp prefix
for f in "${files[@]}"; do
    [[ -n "${file_to_frame[$f]+x}" ]] || continue
    mv -- "$f" "${TMP_PREFIX}${f}"
done

# Phase 2: final names
fail=0
for f in "${files[@]}"; do
    [[ -n "${file_to_frame[$f]+x}" ]] || continue
    src="${TMP_PREFIX}${f}"
    old_frame="${file_to_frame[$f]}"
    old_token="${file_to_token[$f]}"
    new_frame=$(( old_frame + OFFSET ))

    if (( new_frame < 0 )); then
        new_token="-$(printf "%0${OUT_PAD}d" $((-new_frame)))"
    else
        new_token=$(printf "%0${OUT_PAD}d" "$new_frame")
    fi

    # Replace last occurrence of .<old_token>.exr with .<new_token>.exr
    suffix=".${old_token}.exr"
    repl=".${new_token}.exr"
    if [[ "$f" != *"$suffix" ]]; then
        echo "ERROR: token '$suffix' not at end of '$f' — skipping"
        mv -- "$src" "$f"
        fail=1
        continue
    fi
    new_name="${f%$suffix}$repl"

    if [[ -e "$new_name" && "$new_name" != "$f" ]]; then
        echo "ERROR: target exists: $new_name — leaving $src in place"
        fail=1
        continue
    fi

    mv -- "$src" "$new_name"
done

if (( fail )); then
    echo "Done with errors. Some files may still have $TMP_PREFIX prefix."
    exit 2
fi

echo "Done. Renamed ${#files[@]} files."
echo "New range: $((min + OFFSET)) -> $((max + OFFSET))"
