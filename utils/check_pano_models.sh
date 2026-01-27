#!/bin/bash
# Helper script to check and download models for SD-T2I-360PanoImage
# Run this inside the pano-box container after setup

REPO_DIR="$HOME/SD-T2I-360PanoImage"
MODELS_DIR="$REPO_DIR/models"

echo "=== Checking Models Directory ==="

if [ ! -d "$MODELS_DIR" ]; then
    echo "Creating models directory..."
    mkdir -p "$MODELS_DIR"
fi

echo "Checking for required model subdirectories..."

# Check for image-to-pano models
if [ -d "$MODELS_DIR/sd-i2p" ] && [ -f "$MODELS_DIR/sd-i2p/config.json" ]; then
    echo "✅ Found: sd-i2p (image-to-pano)"
else
    echo "❌ Missing: sd-i2p (image-to-pano)"
    echo "   Expected: $MODELS_DIR/sd-i2p/config.json"
fi

# Check for text-to-pano models
if [ -d "$MODELS_DIR/sd-base" ] && [ -f "$MODELS_DIR/sd-base/config.json" ]; then
    echo "✅ Found: sd-base (text-to-pano)"
else
    echo "❌ Missing: sd-base (text-to-pano)"
    echo "   Expected: $MODELS_DIR/sd-base/config.json"
fi

# Check for super resolution models
if [ -d "$MODELS_DIR/sr-base" ] && [ -f "$MODELS_DIR/sr-base/config.json" ]; then
    echo "✅ Found: sr-base (super resolution)"
else
    echo "⚠️  Missing: sr-base (optional, for upscaling)"
fi

if [ -d "$MODELS_DIR/sr-control" ] && [ -f "$MODELS_DIR/sr-control/config.json" ]; then
    echo "✅ Found: sr-control (super resolution control)"
else
    echo "⚠️  Missing: sr-control (optional, for upscaling)"
fi

# Check for RealESRGAN
if [ -f "$MODELS_DIR/RealESRGAN_x2plus.pth" ]; then
    echo "✅ Found: RealESRGAN_x2plus.pth"
else
    echo "⚠️  Missing: RealESRGAN_x2plus.pth (optional, for upscaling)"
fi

echo ""
echo "=== Model Download Instructions ==="
echo ""
echo "Models need to be downloaded manually from:"
echo "  1. Check the GitHub README: https://github.com/ArcherFMY/SD-T2I-360PanoImage"
echo "     - Look for Baidu Disk download links"
echo "     - Download and extract models.zip to: $MODELS_DIR"
echo ""
echo "  2. Alternatively, check HuggingFace for model repositories:"
echo "     - Search for 'SD-T2I-360PanoImage' or 'Diffusion360'"
echo ""
echo "Required structure after extraction:"
echo "  $MODELS_DIR/"
echo "    ├── sd-base/          (required for text-to-pano)"
echo "    │   └── config.json"
echo "    ├── sd-i2p/           (required for image-to-pano)"
echo "    │   └── config.json"
echo "    ├── sr-base/          (optional, for upscaling)"
echo "    ├── sr-control/       (optional, for upscaling)"
echo "    └── RealESRGAN_x2plus.pth  (optional, for upscaling)"
echo ""
echo "After downloading, you can run this script again to verify."
echo ""

