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

    # Get image width to scale font size (~3% of width, min 12px)
    local WIDTH=$(identify -format "%w" "$INPUT" 2>/dev/null)
    local POINTSIZE=$(( WIDTH * 3 / 100 ))
    [ "$POINTSIZE" -lt 12 ] && POINTSIZE=12

    local PAD=$POINTSIZE
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
    tag_file "$f" || EXIT=1
done

exit $EXIT
