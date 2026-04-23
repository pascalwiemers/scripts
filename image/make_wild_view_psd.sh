#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu (folder action)
#
# Build a PSD for a WILD back/detail/front view that matches the reference
# SIDE PSD layer topology exactly.
#
# Pipeline:
#   1. Recursively convert every *.exr under <target> to *.png (oiiotool,
#      scene-linear -> sRGB). Broken *_part.exr renders are skipped.
#      Existing .png outputs are reused (idempotent re-run).
#   2. Invoke make_wild_view_psd.mjs to assemble the final PSD.
#
# Expected input layout (<target> = one view folder):
#   <target>/
#     <model>_<VIEW>_frame_colors_v03/     # flat pool of color EXRs (glossy/matte)
#     paint_masks_aov/                     # paint mask PNGs named paint_masks_aov.<VIEW>_X.png
#     M-TEAM_RS/ M-TEAM_RS_mullet/ MLTD_RS/ MLTD_RS_MULLET/
#     m10/                                 # contains BOTH m10_side_* and m10_mullet_side_*
#     m20/ m20_mullet/
#
# Output: <target>.psd written next to the input folder (4100x2310).
#
# Requires: oiiotool, node, and node_modules/ag-psd in $SCRIPT_DIR (auto-installed).
#
# Usage:
#   make_wild_view_psd.sh              # uses $PWD
#   make_wild_view_psd.sh /path/to/WILD_27_v27_back

set -euo pipefail
shopt -s nullglob

TARGET="${1:-$PWD}"
TARGET="$(realpath "$TARGET")"
[[ -d "$TARGET" ]] || { echo "Not a directory: $TARGET" >&2; exit 1; }

SCRIPT_DIR="/home/mini2/scripts/image"

JOBS="${JOBS:-$(nproc)}"

echo "==> EXR -> PNG in: $TARGET"
find "$TARGET" -type f -iname '*.exr' -not -iname '*_part.exr' -print0 | \
  xargs -0 -r -n1 -P"$JOBS" bash -c '
    in="$1"
    out="${in%.[eE][xX][rR]}.png"
    if [[ -f "$out" ]]; then
      echo "skip (exists): $out"
      exit 0
    fi
    echo "convert: $in"
    if ! oiiotool "$in" --colorconvert role_scene_linear out_srgb -o "$out"; then
      echo "ERROR converting: $in" >&2
      exit 1
    fi
  ' _

if [[ ! -d "$SCRIPT_DIR/node_modules/ag-psd" ]]; then
  echo "==> Installing node deps in $SCRIPT_DIR"
  (cd "$SCRIPT_DIR" && npm install --silent)
fi

echo "==> Building PSD"
notify-send "make_wild_view_psd" "Building PSD for $(basename "$TARGET")..." 2>/dev/null || true
if node "$SCRIPT_DIR/make_wild_view_psd.mjs" "$TARGET"; then
    notify-send "make_wild_view_psd" "Done: $(dirname "$TARGET")/$(basename "$TARGET").psd" 2>/dev/null || true
else
    notify-send "make_wild_view_psd FAILED" "$(basename "$TARGET")" 2>/dev/null || true
    exit 1
fi
