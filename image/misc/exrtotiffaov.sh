#!/bin/bash
# EXR (multi-subimage) → per-AOV TIFFs with normalized RGB channel names.
# Color passes use the review display transform; utility passes retain float data.
set -o pipefail
shopt -s nullglob

EXR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$EXR_SCRIPT_DIR/../../lib/exr_channels.sh" || exit 1

if [ $# -eq 0 ]; then FILES=(*.exr); else FILES=("$@"); fi
(( ${#FILES[@]} == 0 )) && { echo "No .exr files found."; exit 0; }

for INPUT in "${FILES[@]}"; do
  [[ -f "$INPUT" && "$INPUT" == *.exr ]] || { echo "Skipping $INPUT"; continue; }
  base="${INPUT%.exr}"; outdir="${base}_aov"; mkdir -p "$outdir" || exit 1
  echo "Processing: $INPUT → $outdir/"
  INFO=$(oiiotool --info -v -a "$INPUT") || exit 1
  nsi=$(awk '/channel list:/ {n++} END {print n+0}' <<< "$INFO")

  for ((si=0; si<nsi; si++)); do
    # Print info AFTER selecting the subimage; --info on input describes part 0.
    SUB_INFO=$(oiiotool "$INPUT" --subimage "$si" -v --printinfo) || exit 1
    chline=$(sed -n 's/.*channel list: *//p' <<< "$SUB_INFO" | head -1)
    [[ -n "$chline" ]] || { echo "Missing channels: $INPUT part $si" >&2; exit 1; }
    chline="${chline// /}"
    first="${chline%%,*}"
    layer=$(sed -n 's/.*oiio:subimagename: "\(.*\)"/\1/p' <<< "$SUB_INFO" | head -1)
    if [[ -z "$layer" ]]; then
      if [[ "$first" == *.* ]]; then layer="${first%.*}"; else layer="part${si}"; fi
    fi
    safe_layer="${layer//\//_}"
    safe_layer="${safe_layer// /_}"
    out="$outdir/${base##*/}_${safe_layer}.tiff"
    IFS=, read -r -a channels <<< "$chline"
    color=0
    for ch in "${channels[@]}"; do
      case "${ch##*.}" in R|G|B) color=1 ;; esac
    done
    if (( color )); then
      # Preserve the existing per-AOV policy: beauty keeps alpha, light passes
      # are RGB so contributions with zero alpha remain visible.
      alpha_mode=drop
      [[ "$first" != *.* ]] && alpha_mode=keep
      CH_ARGS=$(exr_channel_args_from_list "$chline" "$INPUT part $si" "$alpha_mode") || exit 1
      oiiotool "$INPUT" --subimage "$si" --ch "$CH_ARGS" \
        --colorconvert "ACES - ACEScg" "Output - sRGB" -d uint16 -o "$out" || exit 1
    else
      oiiotool "$INPUT" --subimage "$si" --ch "$chline" \
        --iscolorspace linear -d float -o "$out" || exit 1
    fi
    echo "  → [s$si] $layer: $out"
  done
done
