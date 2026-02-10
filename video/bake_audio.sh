#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu

# Mixes all audio streams/channels in a video down to a single stereo track.
# Video is copied without re-encoding. Output is saved alongside the original
# with a "_stereo" suffix.

process_file() {
    local file="$1"
    local filename=$(basename "$file")
    local dir=$(dirname "$file")
    local extension="${filename##*.}"
    local name_no_ext="${filename%.*}"
    local output="${dir}/${name_no_ext}_stereo.${extension}"

    # Verify the file has at least one audio stream
    local audio_count
    audio_count=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$file" | wc -l)

    if [ "$audio_count" -eq 0 ]; then
        echo "Skipping $file — no audio streams found."
        return
    fi

    echo "Processing $file ($audio_count audio stream(s))..."

    if [ "$audio_count" -le 1 ]; then
        # Single audio stream — downmix to stereo
        ffmpeg -y -i "$file" \
            -map 0:v -map 0:a:0 \
            -c:v copy -ac 2 -c:a aac -b:a 192k \
            "$output"
    else
        # Multiple audio streams — merge all channels then downmix to stereo
        local inputs=""
        for ((i = 0; i < audio_count; i++)); do
            inputs+="[0:a:${i}]"
        done

        ffmpeg -y -i "$file" \
            -filter_complex "${inputs}amerge=inputs=${audio_count}[a]" \
            -map 0:v -map "[a]" \
            -c:v copy -ac 2 -c:a aac -b:a 192k \
            "$output"
    fi

    if [ $? -eq 0 ]; then
        echo "Done: $output"
    else
        echo "Error processing $file"
    fi
}

# Process each file provided as an argument
if [ $# -gt 0 ]; then
    for file in "$@"; do
        if [ -f "$file" ]; then
            process_file "$file"
        else
            echo "File not found: $file"
        fi
    done
else
    # No arguments — process all video files in the current directory
    for file in *; do
        if [[ $(file --mime-type -b "$file") =~ ^video/ ]]; then
            process_file "$file"
        fi
    done
fi

echo "Conversion completed."
