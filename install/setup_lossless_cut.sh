#!/bin/bash
set -e

# --- 1. Download the latest LosslessCut ---
echo "Searching for the latest LosslessCut release..."
LATEST_URL=$(curl -sL https://api.github.com/repos/mifi/lossless-cut/releases/latest | grep "browser_download_url.*AppImage" | head -n 1 | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "Error: Could not find the download URL. Check your internet connection."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading LosslessCut..."
curl -sL "$LATEST_URL" -o "$TMPDIR/LosslessCut.AppImage"
chmod +x "$TMPDIR/LosslessCut.AppImage"

echo "Installing LosslessCut to /usr/local/bin/losslesscut..."
sudo mv "$TMPDIR/LosslessCut.AppImage" /usr/local/bin/losslesscut

# --- 2. Create Dolphin Service Menus (same layout as deploy_dolphin.sh) ---
TARGET_BASE="$HOME/.local/share/kservices5/ServiceMenus"
TARGET_DIR="$TARGET_BASE/video"
mkdir -p "$TARGET_DIR"

echo "Creating Dolphin Service Menus in $TARGET_DIR..."

# Wrapper: decode file:// URLs and run LosslessCut
cat > "$TARGET_DIR/.wrapper_trimVideo.sh" << 'WRAPTRIM'
#!/bin/bash
FILES=()
for url in "$@"; do
    path="$url"
    path="${path#file://}"
    path="${path//%20/ }"
    [ -n "$path" ] && [ -f "$path" ] && FILES+=("$path")
done
if [ ${#FILES[@]} -gt 0 ]; then
    DIR="$(dirname "${FILES[0]}")"
    cd "$DIR" && /usr/local/bin/losslesscut "${FILES[@]}" >/dev/null 2>&1 &
else
    notify-send "Error" "No valid video files selected" 2>/dev/null || true
fi
WRAPTRIM
chmod +x "$TARGET_DIR/.wrapper_trimVideo.sh"

# Wrapper: decode file:// URL and run ffmpeg compress
cat > "$TARGET_DIR/.wrapper_compressVideo.sh" << 'WRAPCOMP'
#!/bin/bash
[ -z "$1" ] && { notify-send "Error" "No file selected" 2>/dev/null || true; exit 0; }
path="$1"
path="${path#file://}"
path="${path//%20/ }"
[ ! -f "$path" ] && { notify-send "Error" "File not found: $path" 2>/dev/null || true; exit 0; }
out="${path%.*}_web.mp4"
dir="$(dirname "$path")"
cd "$dir" && ffmpeg -y -i "$path" -vcodec libx264 -crf 23 -preset fast -acodec aac -movflags +faststart "$out" >/dev/null 2>&1 &
notify-send "Compress" "Started: $(basename "$out")" 2>/dev/null || true
WRAPCOMP
chmod +x "$TARGET_DIR/.wrapper_compressVideo.sh"

# Trim .desktop (X-KDE-ServiceTypes + MimeType like deploy_dolphin)
cat > "$TARGET_DIR/trim-video.desktop" << EOF
[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=KonqPopupMenu/Plugin,video/*
X-KDE-Priority=TopLevel
MimeType=video/*;
Actions=trimVideo;
Icon=video-x-generic

[Desktop Action trimVideo]
Name=1. Trim Video (LosslessCut)
Exec=bash "$TARGET_DIR/.wrapper_trimVideo.sh" %U
EOF

# Compress .desktop
cat > "$TARGET_DIR/compress-video.desktop" << EOF
[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=KonqPopupMenu/Plugin,video/*
X-KDE-Priority=TopLevel
MimeType=video/*;
Actions=compressVideo;
Icon=video-converter

[Desktop Action compressVideo]
Name=2. Compress for Web (MP4)
Exec=bash "$TARGET_DIR/.wrapper_compressVideo.sh" %U
EOF

chmod +x "$TARGET_DIR/trim-video.desktop"
chmod +x "$TARGET_DIR/compress-video.desktop"

# Refresh Dolphin cache (same as deploy_dolphin.sh)
echo "Refreshing Dolphin cache..."
kbuildsycoca5 --noincremental 2>/dev/null || true

echo "-----------------------------------------------"
echo "DONE! LosslessCut + service menus installed."
echo "  Binary: /usr/local/bin/losslesscut"
echo "  Menus:  $TARGET_DIR (video subfolder, same as deploy_dolphin)"
echo "  Restart Dolphin if the new actions do not appear."
echo "  Right-click any video -> Actions -> Trim Video / Compress for Web."
echo "-----------------------------------------------"
