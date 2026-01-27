#!/bin/bash
# Rocky Linux Host Setup Script - Photoshop 2026 Edition
# Installs podman/distrobox and initializes the Arch container

# 1. Install prerequisites on Rocky
sudo dnf install -y podman distrobox

# 2. Create the container (Arch is best for 2026 patched Wine)
distrobox create --name ps-box --image archlinux:latest --yes

# 3. Enter the box and run the internal setup
distrobox enter ps-box -- "
  sudo pacman -Syu --noconfirm base-devel git winetricks winbind samba

  # Install the patched Wine from AUR (Includes PhialsBasement's 2026 fixes)
  git clone https://aur.archlinux.org/wine-photoshop.git /tmp/wine-ps
  cd /tmp/wine-ps && makepkg -si --noconfirm

  # Setup the Wine Prefix
  export WINEPREFIX=\$HOME/.photoshop2026
  wine winecfg /v win10

  # Essential DLLs for the 2026 installer
  winetricks -q atmlib gdiplus msxml3 msxml6 vcrun2015 corefonts
"
echo "Container ready. Now run 'distrobox enter ps-box' and launch your Creative Cloud installer."
