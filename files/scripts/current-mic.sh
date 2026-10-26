#!/usr/bin/env bash
# Print a short label for the current default *input*, mirroring
# current-audio.sh so the bar shows which microphone is live (built-in,
# headset/Bluetooth, USB, ...) next to the speaker indicator.

current_source=$(pactl info 2>/dev/null | grep "Default Source:" | cut -d' ' -f3)

if [ -z "$current_source" ]; then
    echo "N/A"
    exit 0
fi

lc_source=$(echo "$current_source" | tr '[:upper:]' '[:lower:]')

case "$lc_source" in
    *.monitor)
        # A sink monitor is not a microphone; say so rather than claiming IntMic
        echo "None"
        ;;
    *bluez*)
        # Bluetooth headset mic - usually the one with hardware noise cancelling
        echo "BTMic"
        ;;
    *earpods*)
        echo "EarPods"
        ;;
    *hdmi*)
        echo "HDMI"
        ;;
    *analog-input*|*analog-stereo*)
        if echo "$lc_source" | grep -q "usb"; then
            echo "USB"
        else
            # Built-in array mic
            echo "IntMic"
        fi
        ;;
    *usb*)
        echo "USB"
        ;;
    *)
        name=$(echo "$current_source" | sed -e 's/alsa_input\.//' -e 's/\..*//' -e 's/^.*\.//')
        echo "$name"
        ;;
esac
