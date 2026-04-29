#!/bin/bash

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
  echo "Error: ffmpeg is not installed. Please install it using 'sudo dnf install ffmpeg'."
  exit 1
fi

# Check for even number of arguments
if [ "$#" -lt 2 ] || [ $(($# % 2)) -ne 0 ]; then
  echo "Error: Please select an even number of video files."
  exit 1
fi

declare -A left_files
declare -A right_files

# Separate left and right files into respective associative arrays
for file in "$@"; do
  if [[ "$file" =~ _left\.mov$ || "$file" =~ _l\.mov$ || "$file" =~ _Left\.mov$ || "$file" =~ _L\.mov$ ]]; then
    base_name="${file%_*}"
    left_files["$base_name"]="$file"
  elif [[ "$file" =~ _right\.mov$ || "$file" =~ _r\.mov$ || "$file" =~ _Right\.mov$ || "$file" =~ _R\.mov$ ]]; then
    base_name="${file%_*}"
    right_files["$base_name"]="$file"
  else
    echo "Error: Selected files do not match expected naming convention (_left.mov, _L.mov, _right.mov, _R.mov)."
    exit 1
  fi
done

# Merge files
for base_name in "${!left_files[@]}"; do
  left="${left_files[$base_name]}"
  right="${right_files[$base_name]}"

  if [ -n "$right" ]; then
    output="${base_name}.mov"
    color_space=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of default=noprint_wrappers=1:nokey=1 "$left")
    color_primaries=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries -of default=noprint_wrappers=1:nokey=1 "$left")
    color_trc=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=noprint_wrappers=1:nokey=1 "$left")
    ffmpeg -i "$left" -i "$right" \
      -filter_complex "[0:v][1:v]hstack[out];[out]setparams=colorspace=${color_space}:color_primaries=${color_primaries}:color_trc=${color_trc}[final]" \
      -map "[final]" -c:v prores_ks -profile:v 4 -pix_fmt yuva444p10le "$output" || {
      echo "Error: Failed to merge $left and $right."
      exit 1
    }
    echo "Merged $left and $right into $output"
  else
    echo "Error: No matching right file for $left"
  fi
done

echo "Merge completed successfully."
