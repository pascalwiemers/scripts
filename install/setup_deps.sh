#!/bin/bash
# setup_deps.sh - Install all dependencies for the scripts collection on Rocky Linux
# Usage: bash install/setup_deps.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ACES_URL="https://github.com/colour-science/OpenColorIO-Configs/releases/download/v1.2/OpenColorIO-Config-ACES-1.2.zip"
ACES_DIR="$HOME/Documents/aces_1.2"

# ── Preflight ────────────────────────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: Do not run as root. The script uses sudo when needed.${NC}"
    exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "rocky" && "$ID" != "rhel" && "$ID" != "almalinux" ]]; then
        echo -e "${YELLOW}Warning: This script targets Rocky Linux / RHEL / AlmaLinux.${NC}"
        read -rp "Continue anyway? (y/N) " reply
        [[ "$reply" =~ ^[Yy]$ ]] || exit 1
    fi
    RHEL_VERSION=$(rpm -E %rhel 2>/dev/null || echo "9")
else
    echo -e "${RED}Error: Cannot detect OS version${NC}"
    exit 1
fi

echo -e "${GREEN}=== Scripts Dependency Installer ===${NC}"
echo -e "Detected RHEL version: ${BOLD}${RHEL_VERSION}${NC}"
echo ""

# ── Helpers ──────────────────────────────────────────────────────────────────

is_installed() { rpm -q "$1" &>/dev/null; }

install_pkg() {
    local pkg=$1
    if is_installed "$pkg"; then
        echo -e "  ${GREEN}✓${NC} $pkg"
    else
        echo -e "  ${YELLOW}→${NC} Installing $pkg ..."
        if sudo dnf install -y "$pkg" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $pkg"
        else
            echo -e "  ${RED}✗${NC} $pkg (failed)"
            return 1
        fi
    fi
}

ensure_bashrc_line() {
    local line="$1"
    local marker="$2"
    if ! grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "$line" >> "$HOME/.bashrc"
        echo -e "  ${GREEN}+${NC} Added to ~/.bashrc: ${CYAN}${marker}${NC}"
    else
        echo -e "  ${GREEN}✓${NC} Already in ~/.bashrc: ${CYAN}${marker}${NC}"
    fi
}

ensure_bin_dir() {
    mkdir -p "$HOME/bin"
    ensure_bashrc_line 'export PATH="$HOME/bin:$PATH"' '$HOME/bin'
}

download_aces_config() {
    if [[ -f "$ACES_DIR/config.ocio" ]]; then
        echo -e "  ${GREEN}✓${NC} ACES 1.2 config already at $ACES_DIR/config.ocio"
        return 0
    fi
    echo -e "  ${YELLOW}→${NC} Downloading ACES 1.2 config ..."
    local tmpzip
    tmpzip=$(mktemp /tmp/aces_config_XXXXXX.zip)
    if curl -fSL "$ACES_URL" -o "$tmpzip" 2>/dev/null; then
        mkdir -p "$ACES_DIR"
        unzip -qo "$tmpzip" -d "$HOME/Documents/"
        rm -f "$tmpzip"
        if [[ -f "$ACES_DIR/config.ocio" ]]; then
            echo -e "  ${GREEN}✓${NC} ACES 1.2 config installed to $ACES_DIR/"
        else
            echo -e "  ${RED}✗${NC} Extraction succeeded but config.ocio not found at expected path"
            echo -e "  ${YELLOW}  Check ~/Documents/ for the extracted folder name${NC}"
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} Download failed. Install ACES config manually."
        rm -f "$tmpzip"
        return 1
    fi
}

set_ocio_env() {
    ensure_bashrc_line "export OCIO=\"$ACES_DIR/config.ocio\"" 'export OCIO='
}

# ── [1/6] Repositories ──────────────────────────────────────────────────────

echo -e "${GREEN}[1/6] Setting up repositories ...${NC}"

if ! is_installed "epel-release"; then
    echo -e "  ${YELLOW}→${NC} Installing EPEL ..."
    sudo dnf install -y epel-release &>/dev/null
fi
echo -e "  ${GREEN}✓${NC} EPEL"

RPMFUSION_FREE="https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${RHEL_VERSION}.noarch.rpm"
RPMFUSION_NONFREE="https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${RHEL_VERSION}.noarch.rpm"

if ! is_installed "rpmfusion-free-release"; then
    echo -e "  ${YELLOW}→${NC} Installing RPM Fusion Free ..."
    sudo dnf install -y "$RPMFUSION_FREE" &>/dev/null
fi
echo -e "  ${GREEN}✓${NC} RPM Fusion Free"

if ! is_installed "rpmfusion-nonfree-release"; then
    echo -e "  ${YELLOW}→${NC} Installing RPM Fusion Non-Free ..."
    sudo dnf install -y "$RPMFUSION_NONFREE" &>/dev/null
fi
echo -e "  ${GREEN}✓${NC} RPM Fusion Non-Free"

# Enable CRB (CodeReady Builder) for extra build deps
echo -e "  ${YELLOW}→${NC} Enabling CRB ..."
sudo dnf config-manager --set-enabled crb &>/dev/null 2>&1 || true
echo -e "  ${GREEN}✓${NC} CRB"

echo -e "  ${YELLOW}→${NC} Updating package cache ..."
sudo dnf makecache -q &>/dev/null
echo ""

# ── [2/6] Core tools ────────────────────────────────────────────────────────

echo -e "${GREEN}[2/6] Core multimedia & processing tools ...${NC}"
install_pkg "ffmpeg"
install_pkg "ImageMagick"
install_pkg "parallel"
install_pkg "mpv"
echo ""

# ── [3/6] System utilities ──────────────────────────────────────────────────

echo -e "${GREEN}[3/6] System utilities ...${NC}"
install_pkg "rsync"
install_pkg "curl"
install_pkg "jq"
install_pkg "unrtf"
install_pkg "tmux"
install_pkg "btop" || true
install_pkg "nvtop" || true
install_pkg "inotify-tools"
install_pkg "sox"
install_pkg "v4l-utils"
install_pkg "xclip"
install_pkg "xorg-x11-utils"
install_pkg "unzip"
echo ""

# ── [4/6] KDE desktop ───────────────────────────────────────────────────────

echo -e "${GREEN}[4/6] KDE desktop integration ...${NC}"
install_pkg "dolphin" || true
install_pkg "kdialog" || true
install_pkg "konsole" || true
install_pkg "libnotify"
echo ""

# ── [5/6] Python ─────────────────────────────────────────────────────────────

echo -e "${GREEN}[5/6] Python ...${NC}"
install_pkg "python3"
install_pkg "python3-pip"
install_pkg "python3-tkinter"
echo ""

# ── [6/6] OIIO + OCIO ───────────────────────────────────────────────────────

echo -e "${GREEN}[6/6] OIIO + OCIO (oiiotool & color management) ...${NC}"
echo ""
echo -e "${BOLD}How do you want to install oiiotool + OCIO?${NC}"
echo ""
echo "  1) System packages (OpenImageIO-utils from dnf + ACES config download)"
echo "     Simplest. Uses the system oiiotool. Downloads ACES 1.2 to ~/Documents/."
echo ""
echo "  2) Distrobox container (Ubuntu-based oiio-box)"
echo "     Creates Ubuntu 24.04 container with openimageio-tools + OCIO."
echo "     Installs wrapper at ~/bin/oiiotool. Best compatibility."
echo ""
echo "  3) Houdini (use existing hoiiotool)"
echo "     Auto-detects /opt/hfs*/bin/hoiiotool and creates a wrapper."
echo "     Downloads ACES config if not present."
echo ""
echo "  4) Skip (I'll handle this manually)"
echo ""
read -rp "Choice [1-4]: " oiio_choice
echo ""

case "${oiio_choice}" in
    1)
        echo -e "${CYAN}── Option 1: System packages ──${NC}"
        install_pkg "OpenImageIO-utils"
        download_aces_config
        set_ocio_env
        echo -e "  ${GREEN}✓${NC} System oiiotool ready"
        ;;
    2)
        echo -e "${CYAN}── Option 2: Distrobox container ──${NC}"
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ -x "$SCRIPT_DIR/setup_oiio_container.sh" ]]; then
            bash "$SCRIPT_DIR/setup_oiio_container.sh"
        else
            echo -e "${RED}Error: install/setup_oiio_container.sh not found.${NC}"
            echo "  Run it separately: bash install/setup_oiio_container.sh"
            exit 1
        fi
        ;;
    3)
        echo -e "${CYAN}── Option 3: Houdini hoiiotool ──${NC}"
        # Find newest Houdini install
        HFS_DIR=$(ls -d /opt/hfs* 2>/dev/null | sort -V | tail -1)
        if [[ -z "$HFS_DIR" ]]; then
            echo -e "${RED}Error: No Houdini install found in /opt/hfs*${NC}"
            exit 1
        fi
        HOIIOTOOL="$HFS_DIR/bin/hoiiotool"
        if [[ ! -x "$HOIIOTOOL" ]]; then
            echo -e "${RED}Error: hoiiotool not found at $HOIIOTOOL${NC}"
            exit 1
        fi
        echo -e "  ${GREEN}✓${NC} Found Houdini at $HFS_DIR"

        ensure_bin_dir

        # Create wrapper script with LD_LIBRARY_PATH
        cat > "$HOME/bin/oiiotool" <<WRAPPER
#!/bin/bash
# oiiotool wrapper using Houdini's hoiiotool
# Generated by setup_deps.sh
export LD_LIBRARY_PATH="$HFS_DIR/dsolib:\${LD_LIBRARY_PATH:-}"
exec "$HOIIOTOOL" "\$@"
WRAPPER
        chmod +x "$HOME/bin/oiiotool"
        echo -e "  ${GREEN}✓${NC} Created ~/bin/oiiotool wrapper -> $HOIIOTOOL"

        download_aces_config
        set_ocio_env
        echo -e "  ${GREEN}✓${NC} Houdini oiiotool ready"
        ;;
    4)
        echo -e "  ${YELLOW}Skipping OIIO/OCIO setup.${NC}"
        ;;
    *)
        echo -e "  ${YELLOW}Invalid choice, skipping OIIO/OCIO setup.${NC}"
        ;;
esac

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────

echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Installed:"
echo "  Core     : ffmpeg, ImageMagick, parallel, mpv"
echo "  System   : rsync, curl, jq, unrtf, tmux, btop, nvtop, sox, inotify-tools"
echo "  KDE      : dolphin, kdialog, konsole, libnotify, xclip"
echo "  Python   : python3, pip3, tkinter"
case "${oiio_choice}" in
    1) echo "  OIIO/OCIO: system OpenImageIO-utils + ACES 1.2" ;;
    2) echo "  OIIO/OCIO: distrobox oiio-box container + ACES 1.2" ;;
    3) echo "  OIIO/OCIO: Houdini hoiiotool wrapper + ACES 1.2" ;;
    4) echo "  OIIO/OCIO: skipped (manual setup needed)" ;;
esac
echo ""
echo "Next steps:"
echo "  1. Open a new terminal (or 'source ~/.bashrc') to pick up PATH/OCIO changes"
echo "  2. Verify: ffmpeg -version && oiiotool --help && echo \$OCIO"
echo ""
