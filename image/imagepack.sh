#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# imagepack (parallel): convert all *.exr in CWD to JPG/PNG/TIFF/WebP using your scripts,
# and package results into ./package/{jpg,png,tiff,webp,exr}.
# Parallelism defaults to the number of CPU cores; override with: JOBS=8 imagepack

set -euo pipefail
shopt -s nullglob

# --- paths to converters (relative to this script) ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JPG_SCRIPT="$SCRIPT_DIR/exrtojpg.sh"
PNG_SCRIPT="$SCRIPT_DIR/exrtopng.sh"
TIFF_SCRIPT="$SCRIPT_DIR/exrtotiff.sh"
WEBP_SCRIPT="$SCRIPT_DIR/exrtowebp.sh"

# --- sanity checks ---
for s in "$JPG_SCRIPT" "$PNG_SCRIPT" "$TIFF_SCRIPT" "$WEBP_SCRIPT"; do
  [[ -x "$s" ]] || { echo "Error: not executable: $s (chmod +x)"; exit 1; }
done

# --- determine which EXR files to process ---
if [ $# -gt 0 ]; then
  # Files provided as arguments - process only those
  EXRS=()
  for arg in "$@"; do
    # Convert to absolute path and check if it's an EXR file
    if [[ -f "$arg" ]] && [[ "$arg" == *.exr ]]; then
      EXRS+=("$(realpath "$arg")")
    fi
  done
  if (( ${#EXRS[@]} == 0 )); then
    echo "No valid EXR files provided."
    exit 0
  fi
  # Get the directory of the first file for package location
  WORK_DIR="$(dirname "${EXRS[0]}")"
else
  # No arguments - process all *.exr in current directory (original behavior)
  WORK_DIR="$(pwd)"
  EXRS=()
  for f in *.exr; do
    [[ -f "$f" ]] && EXRS+=("$(realpath "$f")")
  done
  if (( ${#EXRS[@]} == 0 )); then
    echo "No .exr files found in current directory."
    exit 0
  fi
fi

# --- prepare package folders ---
PKG_DIR="$WORK_DIR/package"
mkdir -p "$PKG_DIR"/{jpg,png,tiff,webp,exr}

# Copy originals first (idempotent)
for f in "${EXRS[@]}"; do
  # Get just the filename for copying
  fname="$(basename "$f")"
  cp -n -- "$f" "$PKG_DIR/exr/" 2>/dev/null || true
done

# --- parallel convert: one file per job, all four formats per job ---
JOBS="${JOBS:-$(nproc)}"

# Export scripts and PKG_DIR so subshells see them
export JPG_SCRIPT PNG_SCRIPT TIFF_SCRIPT WEBP_SCRIPT PKG_DIR

# Feed EXRs to xargs; handle spaces safely
# Run conversion scripts from PKG_DIR so outputs go directly to PKG_DIR/jpg, etc.
# EXRS already contains absolute paths, so we can use them directly
printf '%s\0' "${EXRS[@]}" | \
xargs -0 -n 1 -P "$JOBS" bash -c '
  set -e
  abs_path="$1"
  echo "→ Converting: $(basename "$abs_path")"
  # Change to PKG_DIR so -folder creates jpg/png/tiff/webp folders here
  cd "$PKG_DIR"
  # Pass absolute path to EXR file so script can find it
  "$JPG_SCRIPT"  -folder "$abs_path" >/dev/null
  "$PNG_SCRIPT"  -folder "$abs_path" >/dev/null
  "$TIFF_SCRIPT" -folder "$abs_path" >/dev/null
  "$WEBP_SCRIPT" -folder "$abs_path" >/dev/null
' _

echo "Done. See $PKG_DIR/{jpg,png,tiff,webp,exr}"
