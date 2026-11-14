#!/bin/sh
# Cycle through available audio sinks

# Get current default sink
current_sink=$(pactl info | grep "Default Sink:" | cut -d' ' -f3)

# Get list of all sinks
sinks=$(pactl list short sinks | awk '{print $2}')
sink_count=$(echo "$sinks" | wc -l)

if [ "$sink_count" -le 1 ]; then
    notify-send "Audio output" "Only one sink available: $current_sink"
    exit 0
fi

# Find current index and next sink
index=1
next_sink=""
for sink in $sinks; do
    if [ "$sink" = "$current_sink" ]; then
        # Calculate next index (wrap around)
        next_index=$((index % sink_count + 1))
        next_sink=$(echo "$sinks" | sed -n "${next_index}p")
        break
    fi
    index=$((index + 1))
done

if [ -n "$next_sink" ]; then
    # Set new default sink
    pactl set-default-sink "$next_sink" 2>/dev/null

    # Move all existing input streams to new sink
    pactl list short sink-inputs 2>/dev/null | while read -r line; do
        input_id=$(echo "$line" | awk '{print $1}')
        pactl move-sink-input "$input_id" "$next_sink" 2>/dev/null
    done

    # Get sink description (without module prefix)
    sink_desc=$(echo "$next_sink" | sed 's/alsa_output\.//' | sed 's/\.analog-stereo//')
    notify-send "Audio output" "Switched to: $sink_desc"
    # waybar's custom/audio module re-runs current-audio.sh every 5 s, so there
    # is no status file to update and no daemon to signal here.
else
    notify-send "Audio output" "Error: Could not find next sink"
fi
