#!/bin/bash
# srgb_to_linear_clip.sh
# Reads a hex color from clipboard, converts sRGB → linear, writes result back to clipboard.
# Requires: xclip (or change to xsel if preferred)
# Usage: Bind to a hotkey or run from terminal after copying a hex value.

HEX=$(xclip -selection clipboard -o 2>/dev/null | tr -d '[:space:]')

# Strip leading # if present
HEX="${HEX#\#}"

# Validate hex (3, 6, or 8 chars)
if [[ ! "$HEX" =~ ^[0-9a-fA-F]{6}$ ]] && [[ ! "$HEX" =~ ^[0-9a-fA-F]{8}$ ]]; then
    notify-send "sRGB→Linear" "Clipboard doesn't contain a valid hex color: #${HEX}" 2>/dev/null
    echo "Error: Clipboard doesn't contain a valid 6 or 8 digit hex color." >&2
    exit 1
fi

R_HEX="${HEX:0:2}"
G_HEX="${HEX:2:2}"
B_HEX="${HEX:4:2}"

# Proper sRGB to linear conversion (exact piecewise formula)
srgb_to_linear() {
    awk -v val="$1" 'BEGIN {
        s = val / 255.0
        if (s <= 0.04045)
            lin = s / 12.92
        else
            lin = ((s + 0.055) / 1.055) ^ 2.4
        # Clamp and convert back to 0-255
        lin = int(lin * 255 + 0.5)
        if (lin < 0) lin = 0
        if (lin > 255) lin = 255
        printf "%02X", lin
    }'
}

R_LIN=$(srgb_to_linear $((16#$R_HEX)))
G_LIN=$(srgb_to_linear $((16#$G_HEX)))
B_LIN=$(srgb_to_linear $((16#$B_HEX)))

RESULT="#${R_LIN}${G_LIN}${B_LIN}"

# Write back to clipboard
echo -n "$RESULT" | xclip -selection clipboard

# Optional notification (comment out if you don't want it)
notify-send "sRGB → Linear" "#${HEX} → ${RESULT}" 2>/dev/null

echo "${RESULT}"
