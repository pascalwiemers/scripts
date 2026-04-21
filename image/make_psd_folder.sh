#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu (folder action)
# EXR -> PNG (recursive, in-place) + PSD build with folder-name groups.
# Usage:
#   make_psd_folder.sh              # uses $PWD
#   make_psd_folder.sh /path/to/dir

set -euo pipefail
shopt -s nullglob

TARGET="${1:-$PWD}"
TARGET="$(realpath "$TARGET")"
[[ -d "$TARGET" ]] || { echo "Not a directory: $TARGET" >&2; exit 1; }

# Worker (.mjs + node_modules) always lives in source location, even when this
# script is deployed via deploy_dolphin.sh to ~/.local/share/kservices5/...
SCRIPT_DIR="/home/mini2/scripts/image"

JOBS="${JOBS:-$(nproc)}"

echo "==> EXR -> PNG in: $TARGET"
find "$TARGET" -type f -iname '*.exr' -print0 | \
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
notify-send "make_psd" "Building PSD for $(basename "$TARGET")..." 2>/dev/null || true
if node "$SCRIPT_DIR/make_psd.mjs" "$TARGET"; then
    notify-send "make_psd" "Done: $(dirname "$TARGET")/$(basename "$TARGET").psd" 2>/dev/null || true
else
    notify-send "make_psd FAILED" "$(basename "$TARGET")" 2>/dev/null || true
    exit 1
fi
