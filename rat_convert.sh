#!/bin/bash
HOUDINI_ICONVERT="/opt/hfs21.0.440/bin/iconvert"
JOBS=8  # adjust based on your CPU cores

convert_file() {
    HOUDINI_ICONVERT="$1"
    file="$2"
    rat_file="${file%.*}.rat"
    if [ ! -f "$rat_file" ]; then
        echo "Converting: $file"
        "$HOUDINI_ICONVERT" "$file" "$rat_file"
    else
        echo "Skipping (already exists): $rat_file"
    fi
}
export -f convert_file

# .hdr first
find . -type f -name "*.hdr" | \
    xargs -P "$JOBS" -I {} bash -c 'convert_file "$@"' _ "$HOUDINI_ICONVERT" {}

# .exr only if no .hdr sibling
find . -type f -name "*.exr" | while read file; do
    [ -f "${file%.*}.hdr" ] && continue
    echo "$file"
done | xargs -P "$JOBS" -I {} bash -c 'convert_file "$@"' _ "$HOUDINI_ICONVERT" {}
