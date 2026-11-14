#!/usr/bin/env bash

# Get mic mute status from PulseAudio
mute_status=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')

if [ "$mute_status" = "yes" ]; then
    echo "Mic: muted"
else
    echo "Mic: on"
fi
