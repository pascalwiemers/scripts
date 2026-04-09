#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu

set -euo pipefail
shopt -s dotglob nullglob

if [ "$#" -eq 0 ]; then
    echo "No folders selected"
    exit 1
fi

DIRS=()
for dir in "$@"; do
    if [ -d "$dir" ]; then
        DIRS+=("$dir")
    fi
done

if [ "${#DIRS[@]}" -eq 0 ]; then
    echo "No valid folders selected"
    exit 1
fi

TARGET_PARENT=$(dirname "${DIRS[0]}")
for dir in "${DIRS[@]}"; do
    if [ "$(dirname "$dir")" != "$TARGET_PARENT" ]; then
        echo "All selected folders must be in the same directory"
        exit 1
    fi
done

COLLECTION_DIR="$TARGET_PARENT/collection"
if [ -e "$COLLECTION_DIR" ]; then
    echo "Target already exists: $COLLECTION_DIR"
    exit 1
fi

mkdir -p "$COLLECTION_DIR"

unique_target_path() {
    local dest_dir="$1"
    local name="$2"
    local candidate="$dest_dir/$name"

    if [ ! -e "$candidate" ]; then
        printf '%s\n' "$candidate"
        return
    fi

    local base ext new_name i=2
    if [[ "$name" == *.* && "$name" != .* ]]; then
        base="${name%.*}"
        ext=".${name##*.}"
    else
        base="$name"
        ext=""
    fi

    while :; do
        new_name="${base}_${i}${ext}"
        candidate="$dest_dir/$new_name"
        if [ ! -e "$candidate" ]; then
            printf '%s\n' "$candidate"
            return
        fi
        i=$((i + 1))
    done
}

copied_count=0
for dir in "${DIRS[@]}"; do
    for item in "$dir"/*; do
        [ -e "$item" ] || continue
        target_path=$(unique_target_path "$COLLECTION_DIR" "$(basename "$item")")
        cp -R "$item" "$target_path"
        copied_count=$((copied_count + 1))
    done
done

echo "Copied contents from ${#DIRS[@]} folder(s) into: $COLLECTION_DIR"
echo "Items copied: $copied_count"
notify-send "Collection created" "Copied $copied_count item(s) into collection" 2>/dev/null || true
