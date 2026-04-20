#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Split EXR layers into individual .exr files.
# Handles multi-part (subimage) EXRs AND single-part channel-prefix layers
# (e.g. diffuse.R/G/B, specular.R/G/B).
# Usage:
#   ./exrsplit.sh
#   ./exrsplit.sh file.exr [file2.exr ...]
# Output: ./layers/<basename>_<layer>.exr

shopt -s nullglob

if [ $# -eq 0 ]; then
    FILES=(*.exr)
    if [ ${#FILES[@]} -eq 0 ]; then
        echo "No .exr files found in current directory."
        exit 0
    fi
else
    FILES=("$@")
fi

mkdir -p layers

JOBS="${JOBS:-$(nproc)}"

printf '%s\0' "${FILES[@]}" | \
xargs -0 -n 1 -P "$JOBS" bash -c '
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && echo "Skip: $INPUT (not a file)" && exit 0
    [[ ! "$INPUT" =~ \.exr$ ]] && echo "Skip: $INPUT (not .exr)" && exit 0

    BASE="$(basename "${INPUT%.exr}")"

    INFO=$(oiiotool -a --info -v "$INPUT" 2>&1)
    SUBIMAGES=$(printf "%s\n" "$INFO" | grep -oP "oiio:subimages:\s*\K[0-9]+" | head -1)
    SUBIMAGES=${SUBIMAGES:-1}

    sanitize() { printf "%s" "$1" | tr -c "A-Za-z0-9._-" "_"; }

    # Extract per-subimage block (starts at " subimage N:" through next subimage or EOF).
    sub_block() {
        local idx="$1"
        printf "%s\n" "$INFO" | awk -v n="$idx" "
            /^ subimage +[0-9]+:/ {
                match(\$0, /[0-9]+/); cur = substr(\$0, RSTART, RLENGTH) + 0;
                in_block = (cur == n); next
            }
            in_block { print }
        "
    }

    if [ "$SUBIMAGES" -gt 1 ]; then
        # Multi-part: extract each subimage to its own file.
        for (( i=0; i<SUBIMAGES; i++ )); do
            SUB_INFO=$(sub_block "$i")
            NAME=$(printf "%s\n" "$SUB_INFO" | grep -oP "oiio:subimagename:\s*\"\K[^\"]+" | head -1)
            [ -z "$NAME" ] && NAME=$(printf "%s\n" "$SUB_INFO" | grep -oP "^\s+name:\s*\"\K[^\"]+" | head -1)
            [ -z "$NAME" ] && NAME="part$i"
            NAME=$(sanitize "$NAME")
            OUT="layers/${BASE}_${NAME}.exr"
            if oiiotool "$INPUT" --subimage "$i" -o "$OUT" 2>/dev/null; then
                echo "$INPUT [subimage $i: $NAME] -> $OUT"
            else
                echo "Error: subimage $i of $INPUT"
            fi
        done
    else
        # Single-part: group channels by prefix before the last "."
        CHANLINE=$(printf "%s\n" "$INFO" | grep -oP "channel list:\s*\K.*" | head -1)
        if [ -z "$CHANLINE" ]; then
            echo "Error: could not read channel list for $INPUT"
            exit 1
        fi
        # Strip spaces, split by comma
        CHANLINE_CLEAN=$(printf "%s" "$CHANLINE" | tr -d " ")
        IFS="," read -ra CHANS <<< "$CHANLINE_CLEAN"

        # Build ordered list of unique prefixes + their channels
        declare -A BUCKET
        PREFIXES=()
        for c in "${CHANS[@]}"; do
            [ -z "$c" ] && continue
            if [[ "$c" == *.* ]]; then
                prefix="${c%.*}"
            else
                prefix="rgba"
            fi
            if [ -z "${BUCKET[$prefix]+x}" ]; then
                PREFIXES+=("$prefix")
                BUCKET[$prefix]="$c"
            else
                BUCKET[$prefix]="${BUCKET[$prefix]},$c"
            fi
        done

        for prefix in "${PREFIXES[@]}"; do
            chans="${BUCKET[$prefix]}"
            # Map to R,G,B,A targets where possible
            CH_ARGS=""
            for target in R G B A; do
                match=""
                IFS="," read -ra LIST <<< "$chans"
                for ch in "${LIST[@]}"; do
                    suffix="${ch##*.}"
                    [ "$ch" = "$suffix" ] && suffix="$ch"  # bare channel w/o prefix
                    if [ "$suffix" = "$target" ]; then
                        match="$ch"
                        break
                    fi
                done
                if [ -n "$match" ]; then
                    [ -n "$CH_ARGS" ] && CH_ARGS+=","
                    CH_ARGS+="${target}=${match}"
                fi
            done
            # Fallback: non-RGBA channels (Z, depth, N.x/y/z, etc.) — pass verbatim
            if [ -z "$CH_ARGS" ]; then
                CH_ARGS="$chans"
            fi
            SAFENAME=$(sanitize "$prefix")
            OUT="layers/${BASE}_${SAFENAME}.exr"
            if oiiotool "$INPUT" --ch "$CH_ARGS" -o "$OUT" 2>/dev/null; then
                echo "$INPUT [$prefix] -> $OUT"
            else
                echo "Error: layer $prefix of $INPUT (channels: $CH_ARGS)"
            fi
        done
    fi
' _
