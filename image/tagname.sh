#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Composite filename (without extension) onto image, save to ./tagged/

# If no input files, glob all supported images in CWD
if [ $# -eq 0 ]; then
    shopt -s nullglob
    set -- *.jpg *.jpeg *.png *.tiff *.tif
    shopt -u nullglob
fi

if [ $# -eq 0 ]; then
    echo "No supported images found."
    exit 1
fi

EXIT=0
JOBS="${JOBS:-$(nproc)}"
FAIL_FILE=$(mktemp)
trap 'rm -f "$FAIL_FILE"' EXIT

tag_file() {
    local INPUT="$1"
    [[ ! -f "$INPUT" ]] && echo "Missing: $INPUT" && return 1

    local EXT="${INPUT##*.}"
    local EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
    case "$EXT_LOWER" in
        jpg|jpeg|png|tiff|tif) ;;
        *) echo "Skip: $INPUT" && return 0 ;;
    esac

    local DIR=$(dirname "$INPUT")
    local BASE=$(basename "$INPUT")
    local NAME="${BASE%.*}"

    mkdir -p "$DIR/tagged"
    local OUT="$DIR/tagged/$BASE"

    # Get image width to scale font size (~1.5% of width, min 6px)
    local WIDTH=$(identify -format "%w" "$INPUT" 2>/dev/null)
    local POINTSIZE=$(( WIDTH * 15 / 1000 ))
    [ "$POINTSIZE" -lt 6 ] && POINTSIZE=6

    local PAD=$(( POINTSIZE / 3 ))
    [ "$PAD" -lt 2 ] && PAD=2
    local SW=$(( POINTSIZE / 12 ))
    [ "$SW" -lt 1 ] && SW=1

    convert "$INPUT" \
        -font Helvetica \
        -pointsize "$POINTSIZE" \
        -gravity NorthWest \
        -stroke black -strokewidth "$SW" -fill black \
        -annotate +${PAD}+${PAD} "$NAME" \
        -stroke none -fill white \
        -annotate +${PAD}+${PAD} "$NAME" \
        "$OUT"

    if [ $? -eq 0 ]; then
        echo "$INPUT -> $OUT"
    else
        echo "Error on $INPUT"
        return 1
    fi
}

for f in "$@"; do
    ( tag_file "$f" || echo 1 >> "$FAIL_FILE" ) &
    while (( $(jobs -rp | wc -l) >= JOBS )); do
        wait -n 2>/dev/null || break
    done
done
wait

[ -s "$FAIL_FILE" ] && EXIT=1
exit $EXIT
