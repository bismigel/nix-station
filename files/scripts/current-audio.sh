#!/usr/bin/env bash
# Output current audio sink as a short label for waybar (custom/audio).

current_sink=$(pactl info 2>/dev/null | grep "Default Sink:" | cut -d' ' -f3)

if [ -z "$current_sink" ]; then
    echo "N/A"
    exit 0
fi

# Simplify sink name using lowercase matching
lc_sink=$(echo "$current_sink" | tr '[:upper:]' '[:lower:]')

case "$lc_sink" in
    *earpods*)
        echo "EarPods"
        ;;
    *bluez*)
        echo "BT"
        ;;
    *hdmi*)
        echo "HDMI"
        ;;
    *analog-stereo*)
        # Built-in audio
        if echo "$current_sink" | grep -q "usb"; then
            echo "USB"
        else
            echo "Speaker"
        fi
        ;;
    *usb*)
        echo "USB"
        ;;
    *)
        # Extract short name
        name=$(echo "$current_sink" | sed -e 's/alsa_output\.//' -e 's/\..*//' -e 's/^.*\.//')
        echo "$name"
        ;;
esac
