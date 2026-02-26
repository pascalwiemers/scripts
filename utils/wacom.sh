#!/bin/bash

mapfile -t MONITORS < <(xrandr --query | grep " connected" | sed 's/ primary / /' | awk '{print $1 " " $3}')

resolve_target() {
    local choice="$1"
    local total="${#MONITORS[@]}"

    if [[ "$choice" == "all" ]]; then
        echo "desktop"
        return
    fi

    # Match by monitor name (e.g. HDMI-1, DP-2)
    for mon in "${MONITORS[@]}"; do
        name=$(echo "$mon" | awk '{print $1}')
        if [[ "$name" == "$choice" ]]; then
            geo=$(echo "$mon" | awk '{print $2}')
            if [[ $geo =~ [0-9]+x[0-9]+ ]]; then
                echo "$geo"
            else
                echo "$name"
            fi
            return
        fi
    done

    # Match by 1-based index
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= total )); then
        local idx=$((choice - 1))
        geo=$(echo "${MONITORS[$idx]}" | awk '{print $2}')
        if [[ $geo =~ [0-9]+x[0-9]+ ]]; then
            echo "$geo"
        else
            echo "${MONITORS[$idx]}" | awk '{print $1}'
        fi
        return
    fi

    echo ""
}

apply_mapping() {
    local target="$1"
    local devices
    devices=$(xsetwacom --list devices | sed 's/id:.*//' | sed 's/[[:space:]]*$//')

    while IFS= read -r device_name; do
        if [ -n "$device_name" ]; then
            xsetwacom set "$device_name" MapToOutput "$target"
            if [ $? -eq 0 ]; then
                echo "Mapped '$device_name' → $target"
            else
                echo "Failed to map '$device_name'"
            fi
        fi
    done <<< "$devices"
}

# --- Flag mode ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --list|-l)
            i=1
            for mon in "${MONITORS[@]}"; do
                echo "$i) $mon"
                ((i++))
            done
            echo "$i) all  (Full Desktop)"
            ;;
        --all|-a)
            echo "Setting to: Full Desktop"
            apply_mapping "desktop"
            ;;
        --monitor|-m)
            TARGET=$(resolve_target "$2")
            if [[ -z "$TARGET" ]]; then
                echo "Unknown monitor: $2"
                echo "Run with --list to see available monitors."
                exit 1
            fi
            echo "Setting to: $TARGET"
            apply_mapping "$TARGET"
            ;;
        *)
            # Allow bare argument: wacom.sh HDMI-1  or  wacom.sh 2  or  wacom.sh all
            TARGET=$(resolve_target "$1")
            if [[ -z "$TARGET" ]]; then
                echo "Unknown monitor: $1"
                echo "Run with --list to see available monitors."
                exit 1
            fi
            echo "Setting to: $TARGET"
            apply_mapping "$TARGET"
            ;;
    esac
    exit 0
fi

# --- Interactive mode ---
echo "------------------------------------------"
echo " Wacom Display Mapper"
echo "------------------------------------------"
echo "Select an output:"

i=1
for mon in "${MONITORS[@]}"; do
    echo "$i) $mon"
    ((i++))
done
echo "$i) All Monitors (Full Desktop)"
echo "------------------------------------------"

read -p "Enter choice [1-$i]: " CHOICE

if [ "$CHOICE" -eq "$i" ]; then
    TARGET="desktop"
    echo "Setting to: Full Desktop"
else
    TARGET=$(resolve_target "$CHOICE")
    if [[ -z "$TARGET" ]]; then
        echo "Invalid choice."
        exit 1
    fi
    echo "Setting to: $TARGET"
fi

apply_mapping "$TARGET"
echo "Done!"
