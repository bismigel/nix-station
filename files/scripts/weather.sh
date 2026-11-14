#!/usr/bin/env bash
# Weather fetcher (Open-Meteo) for waybar custom/weather.

# Toronto coordinates
LAT="43.70"
LON="-79.42"

# Get weather data
WEATHER_DATA=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,weather_code&temperature_unit=celsius&timezone=auto")

if [ -n "$WEATHER_DATA" ]; then
    # Extract values using jq
    TEMP=$(echo "$WEATHER_DATA" | jq -r '.current.temperature_2m')
    HUMIDITY=$(echo "$WEATHER_DATA" | jq -r '.current.relative_humidity_2m')
    CODE=$(echo "$WEATHER_DATA" | jq -r '.current.weather_code')

    # Round temperature to nearest integer
    TEMP_INT=$(printf "%.0f" "$TEMP")

    # Simple weather code to text mapping
    case $CODE in
        0) TEXT="Sun" ;;
        1|2|3) TEXT="Cloudy" ;;
        45|48) TEXT="Fog" ;;
        51|53|55|56|57) TEXT="Drizzle" ;;
        61|63|65|66|67) TEXT="Rain" ;;
        71|73|75|77) TEXT="Snow" ;;
        80|81|82) TEXT="Rain" ;;
        85|86) TEXT="Snow" ;;
        95|96|99) TEXT="Storm" ;;
        *) TEXT="N/A" ;;
    esac

    echo "${TEMP_INT}°C ${TEXT} H:${HUMIDITY}%"
else
    echo "Weather: N/A"
fi
