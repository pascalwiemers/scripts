#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# Convert PDF → JPG using pdftoppm at 300 DPI.
# If no inputs, process all *.pdf in current directory.
# Output goes into a pdftojpg/ subfolder.

if ! command -v pdftoppm &>/dev/null; then
    echo "Error: pdftoppm not found. Install poppler-utils:"
    echo "  sudo dnf install poppler-utils"
    exit 1
fi

# If no input files passed, use all .pdf in CWD
if [ $# -eq 0 ]; then
    set -- *.pdf
fi

# If no .pdf found
if [ "$1" = "*.pdf" ]; then
    echo "No .pdf files found."
    exit 1
fi

OUTDIR="pdftojpg"
mkdir -p "$OUTDIR"

convert_file() {
    local INPUT="$1"
    [[ ! -f "$INPUT" ]] && echo "Missing: $INPUT" && return 1
    [[ ! "$INPUT" =~ \.[pP][dD][fF]$ ]] && echo "Skip: $INPUT" && return 0

    local BASE
    BASE=$(basename "${INPUT%.[pP][dD][fF]}")

    pdftoppm -jpeg -r 300 "$INPUT" "$OUTDIR/$BASE"
    [[ $? -eq 0 ]] && echo "$INPUT → $OUTDIR/${BASE}-*.jpg" || echo "Error on $INPUT"
}

EXIT=0
for f in "$@"; do
    convert_file "$f" || EXIT=1
done

exit $EXIT
