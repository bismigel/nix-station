#!/usr/bin/env bash
# Poll weather.sh into /tmp/weather.txt for waybar custom/weather.

WEATHER_FILE="/tmp/weather.txt"
PID_FILE="/tmp/weather.pid"
SCRIPT_DIR="$(dirname "$0")"

# Ensure weather file exists immediately
echo "Weather: N/A" > "$WEATHER_FILE"

# Write PID
echo $$ > "$PID_FILE"

# Clean up on exit (don't remove weather file, just PID)
trap 'rm -f "$PID_FILE"; exit' INT TERM EXIT

while true; do
    # Run weather script and capture output
    if OUTPUT=$("$SCRIPT_DIR/weather.sh" 2>/dev/null); then
        echo "$OUTPUT" > "$WEATHER_FILE"
    else
        # If script fails, keep old data but mark as stale
        if [ -f "$WEATHER_FILE" ]; then
            # Keep existing data but add (stale) marker
            CONTENT=$(cat "$WEATHER_FILE")
            echo "$CONTENT (stale)" > "$WEATHER_FILE"
        else
            echo "Weather: N/A" > "$WEATHER_FILE"
        fi
    fi

    # Sleep 2 minutes (120 seconds) for more frequent updates
    sleep 120
done
