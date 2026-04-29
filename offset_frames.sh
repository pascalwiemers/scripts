#!/usr/bin/env bash
# @kde
#
# offset_frames.sh
# Detect most negative frame in EXR sequence, shift entire sequence so
# lowest frame becomes START_FRAME.
#
# Usage:
#   ./offset_frames.sh [directory ...] [start_frame]
#
# Defaults:
#   directory   = current working directory
#   start_frame = 1 (or env OFFSET_FRAMES_START)
#
# When multiple directories are given, each is processed as its own
# independent sequence. Trailing integer arg (not an existing dir) is
# treated as start_frame.
#
# Filename pattern: <name>[._]<frame>.exr   (frame may be negative: -0049)
# Frame separator may be '.' or '_'; preserved per file.
# Output pad width derived from input token width (longest token wins).

set -euo pipefail

START_FRAME="${OFFSET_FRAMES_START:-1}"

args=( "$@" )
if (( ${#args[@]} >= 1 )); then
    last="${args[${#args[@]}-1]}"
    if [[ "$last" =~ ^-?[0-9]+$ ]] && [[ ! -d "$last" ]]; then
        START_FRAME="$last"
        unset 'args[${#args[@]}-1]'
    fi
fi

dirs=( "${args[@]}" )
(( ${#dirs[@]} == 0 )) && dirs=( "." )

process_dir() {
    local DIR="$1"
    local START_FRAME="$2"

    if [[ ! -d "$DIR" ]]; then
        echo "ERROR: not a directory: $DIR" >&2
        return 1
    fi

    pushd "$DIR" >/dev/null

    shopt -s nullglob
    local -a files=( *.exr )
    if (( ${#files[@]} == 0 )); then
        echo "No .exr files found in $DIR"
        popd >/dev/null
        return 0
    fi

    local -a frames=()
    local -A file_to_frame=()
    local -A file_to_token=()
    local -A file_to_sep=()

    local frame_re='([._])(-?[0-9]+)\.exr$'
    local token_width=0
    local f sep raw num
    for f in "${files[@]}"; do
        if [[ "$f" =~ $frame_re ]]; then
            sep="${BASH_REMATCH[1]}"
            raw="${BASH_REMATCH[2]}"
            if [[ "$raw" == -* ]]; then
                num=$((-1 * 10#${raw#-}))
            else
                num=$((10#$raw))
            fi
            frames+=( "$num" )
            file_to_frame["$f"]="$num"
            file_to_token["$f"]="$raw"
            file_to_sep["$f"]="$sep"
            (( ${#raw} > token_width )) && token_width=${#raw}
        else
            echo "WARN: skipping unrecognised filename: $f"
        fi
    done

    local OUT_PAD=$token_width

    if (( ${#frames[@]} == 0 )); then
        echo "No files matched frame pattern in $DIR."
        popd >/dev/null
        return 0
    fi

    local min=${frames[0]} max=${frames[0]} n
    for n in "${frames[@]}"; do
        (( n < min )) && min=$n
        (( n > max )) && max=$n
    done

    local OFFSET=$(( START_FRAME - min ))

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
        popd >/dev/null
        return 0
    fi

    if [[ -z "${OFFSET_FRAMES_YES:-}" ]]; then
        local ans
        read -r -p "Proceed with rename in $DIR? [y/N] " ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            echo "Skipped $DIR."
            popd >/dev/null
            return 0
        fi
    fi

    local TMP_PREFIX=".__renaming__"

    for f in "${files[@]}"; do
        [[ -n "${file_to_frame[$f]+x}" ]] || continue
        mv -- "$f" "${TMP_PREFIX}${f}"
    done

    local fail=0 src old_frame old_token new_frame new_token suffix repl new_name neg_pad
    for f in "${files[@]}"; do
        [[ -n "${file_to_frame[$f]+x}" ]] || continue
        src="${TMP_PREFIX}${f}"
        old_frame="${file_to_frame[$f]}"
        old_token="${file_to_token[$f]}"
        new_frame=$(( old_frame + OFFSET ))

        sep="${file_to_sep[$f]}"
        if (( new_frame < 0 )); then
            neg_pad=$(( OUT_PAD - 1 ))
            (( neg_pad < 1 )) && neg_pad=1
            new_token="-$(printf "%0${neg_pad}d" $((-new_frame)))"
        else
            new_token=$(printf "%0${OUT_PAD}d" "$new_frame")
        fi

        suffix="${sep}${old_token}.exr"
        repl="${sep}${new_token}.exr"
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
        echo "Done with errors in $DIR. Some files may still have $TMP_PREFIX prefix."
        popd >/dev/null
        return 2
    fi

    echo "Done $DIR. Renamed ${#files[@]} files. New range: $((min + OFFSET)) -> $((max + OFFSET))"
    popd >/dev/null
    return 0
}

overall_rc=0
for d in "${dirs[@]}"; do
    if ! process_dir "$d" "$START_FRAME"; then
        rc=$?
        (( rc > overall_rc )) && overall_rc=$rc
    fi
done
exit "$overall_rc"
