#!/usr/bin/env bash
# Refresh Dolphin service menu cache and restart Dolphin.
# Use after adding/editing ~/.local/share/kservices5/ServiceMenus/ (or kio/servicemenus).

set -e

echo "Refreshing Dolphin cache..."
if kbuildsycoca5 --noincremental 2>/dev/null; then
    echo "Cache refreshed."
else
    echo "Warning: kbuildsycoca5 not found or failed (try kbuildsycoca6 on Plasma 6)."
fi

echo "Restarting Dolphin..."

close_dolphin() {
    if ! pgrep -x dolphin >/dev/null 2>&1; then
        return 0
    fi
    if command -v qdbus &>/dev/null; then
        for service in $(qdbus --session 2>/dev/null | grep -i dolphin || true); do
            qdbus "$service" /MainApplication quit 2>/dev/null || true
        done
    elif command -v dbus-send &>/dev/null; then
        for service in org.kde.dolphin org.kde.dolphin-*; do
            dbus-send --session --type=method_call --dest="$service" /MainApplication org.qtproject.Qt.QApplication.quit 2>/dev/null || true
        done
    fi
    sleep 1
    if pgrep -x dolphin >/dev/null 2>&1; then
        killall dolphin 2>/dev/null || true
        sleep 0.5
    fi
}

close_dolphin

if command -v dolphin &>/dev/null; then
    dolphin >/dev/null 2>&1 &
    echo "Dolphin restarted."
else
    echo "Warning: dolphin not found in PATH."
    exit 1
fi
