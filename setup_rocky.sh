#!/bin/bash
# setup_rocky.sh - Install all dependencies for scripts on Rocky OS
# Excludes: OCIO, OpenImageIO/oiio, ACES (install separately if needed)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Do not run this script as root. It will use sudo when needed.${NC}" 
   exit 1
fi

echo -e "${GREEN}=== Rocky OS Scripts Setup ===${NC}"
echo "This script will install all dependencies for the scripts collection."
echo "Excluding: OCIO, OpenImageIO/oiio, ACES (install separately if needed)"
echo ""

# Detect RHEL version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "rocky" && "$ID" != "rhel" && "$ID" != "almalinux" ]]; then
        echo -e "${YELLOW}Warning: This script is designed for Rocky Linux/RHEL/AlmaLinux${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    RHEL_VERSION=$(rpm -E %rhel 2>/dev/null || echo "9")
else
    echo -e "${RED}Error: Cannot detect OS version${NC}"
    exit 1
fi

echo -e "${GREEN}Detected RHEL version: $RHEL_VERSION${NC}"
echo ""

# Function to check if a package is installed
is_installed() {
    rpm -q "$1" &>/dev/null
}

# Function to install package if not installed
install_if_missing() {
    local pkg=$1
    if is_installed "$pkg"; then
        echo -e "  ${GREEN}✓${NC} $pkg (already installed)"
    else
        echo -e "  ${YELLOW}→${NC} Installing $pkg..."
        sudo dnf install -y "$pkg" || {
            echo -e "  ${RED}✗${NC} Failed to install $pkg"
            return 1
        }
        echo -e "  ${GREEN}✓${NC} $pkg installed"
    fi
}

# Step 1: Enable EPEL and RPM Fusion
echo -e "${GREEN}[1/5] Setting up repositories...${NC}"
if ! is_installed "epel-release"; then
    echo "  Installing EPEL repository..."
    sudo dnf install -y epel-release || {
        echo -e "${RED}Error: Failed to install EPEL${NC}"
        exit 1
    }
else
    echo -e "  ${GREEN}✓${NC} EPEL already enabled"
fi

# RPM Fusion repositories
RPMFUSION_FREE="https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${RHEL_VERSION}.noarch.rpm"
RPMFUSION_NONFREE="https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${RHEL_VERSION}.noarch.rpm"

if ! is_installed "rpmfusion-free-release"; then
    echo "  Installing RPM Fusion Free repository..."
    sudo dnf install -y "$RPMFUSION_FREE" || {
        echo -e "${RED}Error: Failed to install RPM Fusion Free${NC}"
        exit 1
    }
else
    echo -e "  ${GREEN}✓${NC} RPM Fusion Free already enabled"
fi

if ! is_installed "rpmfusion-nonfree-release"; then
    echo "  Installing RPM Fusion Non-Free repository..."
    sudo dnf install -y "$RPMFUSION_NONFREE" || {
        echo -e "${RED}Error: Failed to install RPM Fusion Non-Free${NC}"
        exit 1
    }
else
    echo -e "  ${GREEN}✓${NC} RPM Fusion Non-Free already enabled"
fi

# Update package cache
echo "  Updating package cache..."
sudo dnf makecache

echo ""

# Step 2: Core multimedia tools
echo -e "${GREEN}[2/5] Installing core multimedia tools...${NC}"
install_if_missing "ffmpeg"
install_if_missing "ffmpeg-devel" || true  # Optional, for development
install_if_missing "mpv"
install_if_missing "vlc" || echo -e "  ${YELLOW}⚠${NC} VLC not available in default repos (optional)"

echo ""

# Step 3: Image processing tools
echo -e "${GREEN}[3/5] Installing image processing tools...${NC}"
install_if_missing "ImageMagick"
install_if_missing "ImageMagick-devel" || true  # Optional

echo ""

# Step 4: System utilities and desktop tools
echo -e "${GREEN}[4/5] Installing system utilities and desktop tools...${NC}"

# Parallel processing
install_if_missing "parallel"

# GUI tools
install_if_missing "yad" || {
    echo -e "  ${YELLOW}⚠${NC} yad not found in default repos"
    echo -e "  ${YELLOW}  You may need to install from source or COPR:${NC}"
    echo -e "  ${YELLOW}  dnf copr enable thomas-saenger/yad && dnf install yad${NC}"
}

# Desktop environment (KDE)
install_if_missing "dolphin" || echo -e "  ${YELLOW}⚠${NC} Dolphin not found (KDE not installed?)"
install_if_missing "kdialog" || echo -e "  ${YELLOW}⚠${NC} kdialog not found (KDE not installed?)"
install_if_missing "konsole" || echo -e "  ${YELLOW}⚠${NC} Konsole not found (KDE not installed?)"

# Notifications
install_if_missing "libnotify"

# Clipboard tools
install_if_missing "xclip"
install_if_missing "xsel" || true  # Optional alternative
# wl-clipboard is for Wayland, typically not in repos - would need manual install

# Video/audio device access
install_if_missing "v4l-utils"

# Audio processing
install_if_missing "sox"

# Network/API tools
install_if_missing "curl"
install_if_missing "jq"

# File watching
install_if_missing "inotify-tools"

# File syncing
install_if_missing "rsync"

# X11 utilities
install_if_missing "xorg-x11-utils"

# Wacom tablet support
install_if_missing "xorg-x11-drv-wacom" || echo -e "  ${YELLOW}⚠${NC} Wacom driver not available (optional)"

# Document conversion
install_if_missing "unrtf"

echo ""

# Step 5: Python tools (if needed for some scripts)
echo -e "${GREEN}[5/5] Checking Python tools...${NC}"
if command -v python3 &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Python 3 is available"
    # Check for pip
    if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} pip is available"
    else
        echo -e "  ${YELLOW}⚠${NC} pip not found, installing python3-pip..."
        install_if_missing "python3-pip"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Python 3 not found, installing..."
    install_if_missing "python3"
    install_if_missing "python3-pip"
fi

echo ""

# Summary
echo -e "${GREEN}=== Installation Summary ===${NC}"
echo ""
echo "Core tools installed:"
echo "  ✓ ffmpeg - Video processing"
echo "  ✓ ImageMagick - Image processing"
echo "  ✓ GNU parallel - Parallel processing"
echo "  ✓ mpv - Video player"
echo ""
echo "Desktop tools installed:"
echo "  ✓ dolphin - File manager (KDE)"
echo "  ✓ kdialog - KDE dialogs"
echo "  ✓ konsole - Terminal emulator (KDE)"
echo "  ✓ libnotify - Desktop notifications"
echo "  ✓ xclip - Clipboard tool"
echo ""
echo "System utilities installed:"
echo "  ✓ v4l-utils - Video device access"
echo "  ✓ sox - Audio processing"
echo "  ✓ curl, jq - Network/API tools"
echo "  ✓ inotify-tools - File watching"
echo "  ✓ rsync - File syncing"
echo ""
echo -e "${YELLOW}Note: The following are NOT installed by this script:${NC}"
echo "  • OCIO (Color management - install separately)"
echo "  • OpenImageIO/oiio (EXR tools - install separately)"
echo "  • ACES (Color transforms - install separately)"
echo "  • DJV (Image viewer - install from /opt/djv or source)"
echo "  • Whisper (Python transcription - install via pip/conda)"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Add scripts directory to PATH (if not already):"
echo "     export PATH=\"\$PATH:$(pwd)\""
echo "  2. Install OCIO/oiio/ACES separately if needed for EXR workflows"
echo "  3. Test scripts with: ffmpeg -version, convert -version, parallel --version"
echo ""

