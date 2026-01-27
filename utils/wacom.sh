#!/bin/bash

# 1. Get a list of connected monitors and their geometries
# We store them in an array
mapfile -t MONITORS < <(xrandr --query | grep " connected" | awk '{print $1 " " $3}' | sed 's/primary //')

echo "------------------------------------------"
echo " Wacom Display Mapper"
echo "------------------------------------------"
echo "Select an output:"

# 2. List monitors for selection
i=1
for mon in "${MONITORS[@]}"; do
    echo "$i) Monitor: $mon"
    ((i++))
done
echo "$i) All Monitors (Full Desktop)"
echo "------------------------------------------"

read -p "Enter choice [1-$i]: " CHOICE

# 3. Determine the target based on user input
if [ "$CHOICE" -eq "$i" ]; then
    TARGET="desktop"
    echo "Setting to: Full Desktop"
else
    # Subtract 1 because arrays are 0-indexed
    INDEX=$((CHOICE - 1))
    # Extract just the geometry (e.g., 1920x1080+0+0) or name
    # We'll use the geometry as it's more reliable on your system
    TARGET=$(echo "${MONITORS[$INDEX]}" | awk '{print $2}')

    # Check if the target is just a name (like 'connected'),
    # extract the geometry properly if needed
    if [[ ! $TARGET =~ [0-9]+x[0-9]+ ]]; then
        TARGET=$(echo "${MONITORS[$INDEX]}" | awk '{print $1}')
    fi
    echo "Setting to: $TARGET"
fi

# 4. Apply to all Wacom devices
devices=$(xsetwacom --list devices | sed 's/id:.*//' | sed 's/[[:space:]]*$//')

while IFS= read -r device_name; do
    if [ -n "$device_name" ]; then
        xsetwacom set "$device_name" MapToOutput "$TARGET"
        if [ $? -eq 0 ]; then
            echo "Successfully mapped '$device_name'"
        else
            # Final fallback to HEAD index if geometry fails
            FALLBACK="HEAD$((CHOICE - 1))"
            xsetwacom set "$device_name" MapToOutput "$FALLBACK"
        fi
    fi
done <<< "$devices"

echo "Done!"
