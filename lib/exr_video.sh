#!/usr/bin/env bash
# Shared frame-rate policy for display-ready EXR videos.

exr_valid_fps() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ || "$value" =~ ^[0-9]+/[0-9]+$ ]] || return 1
    awk -v rate="$value" 'BEGIN {
        split(rate, parts, "/")
        exit !(parts[1] > 0 && (index(rate, "/") == 0 || parts[2] > 0))
    }'
}

exr_video_fps() {
    local input="$1" override="${2:-}" info rate
    # Explicit command-line choice wins; otherwise inspect the first frame.
    if [[ -n "$override" ]]; then
        exr_valid_fps "$override" || { echo "Invalid FPS: $override" >&2; return 1; }
        printf '%s\n' "$override"
        return 0
    fi
    info=$(oiiotool --info -v "$input") || return 1
    rate=$(awk '/^[[:space:]]*FramesPerSecond:/ {print $2; exit}' <<< "$info")
    rate=${rate//\"/}
    if exr_valid_fps "$rate"; then
        printf '%s\n' "$rate"
    else
        printf '30\n'
    fi
}

exr_video_link_frames() {
    local directory="$1" frame link index=0
    # image2 decodes PNGs in parallel. Numbered links retain natural filename
    # order even when source numbering has gaps or inconsistent padding.
    mkdir "$directory/frames" || return 1
    while IFS= read -r -d '' frame; do
        printf -v link '%s/frames/%08d.png' "$directory" "$index"
        ln -s "$frame" "$link" || return 1
        index=$((index + 1))
    done < <(find "$directory" -maxdepth 1 -type f -name '*_converted.png' -print0 | sort -z -V)
    (( index > 0 )) || { echo "No converted PNG frames found in $directory" >&2; return 1; }
}
