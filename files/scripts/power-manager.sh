#!/usr/bin/env bash
# Power manager for Sway/Wayland.
#
# Switches the panel refresh rate based on AC/battery, like the old xrandr
# version did, and notifies on change.
#
# Portable across panels: it reads the current resolution and the refresh rates
# the panel actually advertises from sway, instead of hardcoding one laptop's
# numbers. AC prefers AC_RATE (falling back to the highest available); battery
# prefers BAT_RATE (falling back to the lowest available).

# --- CONFIGURATION ---
AC_RATE=120
BAT_RATE=60

# Resolve jq even if the session PATH is minimal.
JQ="$(command -v jq 2>/dev/null || true)"
if [ -z "$JQ" ]; then
    for _c in "/etc/profiles/per-user/$(id -un)/bin/jq" /run/current-system/sw/bin/jq; do
        [ -x "$_c" ] && JQ="$_c" && break
    done
fi
JQ="${JQ:-jq}"

MONITOR="$(swaymsg -t get_outputs -r 2>/dev/null | "$JQ" -r '.[] | select(.focused == true) | .name' | head -1)"
MONITOR="${MONITOR:-eDP-1}"

AC_PATH=""
for _ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ACAD/online; do
    [ -f "$_ac" ] && AC_PATH="$_ac" && break
done
AC_PATH="${AC_PATH:-/sys/class/power_supply/AC0/online}"

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$RUNTIME/power-manager.lock"
STATE_FILE="$RUNTIME/power_state_last"

# --- LOGGING ---
LOG_FILE="${LOG_FILE:-/tmp/power-manager.log}"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG_FILE"
    if [ -t 0 ]; then
        echo "$(date '+%H:%M:%S') $*"
    fi
}

# Check if AC path exists
if [ ! -f "$AC_PATH" ]; then
    notify-send -u critical "Power Manager" "Error: $AC_PATH not found"
    exit 1
fi

# Singleton via flock: auto-released when the process dies, so a stale file or
# a reused PID can never wedge the next start.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Power manager already running"
    exit 0
fi
log "Power manager started (PID: $$)"

# --- MODE DISCOVERY ---
sway_outputs() { swaymsg -t get_outputs -r 2>/dev/null; }
current_res() {
    sway_outputs | "$JQ" -r --arg m "$MONITOR" \
        '.[] | select(.name==$m) | "\(.current_mode.width)x\(.current_mode.height)"' 2>/dev/null | head -1
}
available_rates() { # $1 = WxH -> integer Hz values, ascending
    sway_outputs | "$JQ" -r --arg m "$MONITOR" --arg res "$1" \
        '.[] | select(.name==$m) | .modes[] | select("\(.width)x\(.height)"==$res) | (.refresh/1000|round)' 2>/dev/null \
        | sort -n | uniq
}

# --- APPLY ---
apply_power_settings() {
    local status=$1 res rates target
    res="$(current_res)"
    res="${res:-2560x1600}"
    rates="$(available_rates "$res")"

    if [ "$status" = "1" ]; then
        # --- PLUGGED IN ---
        if echo "$rates" | grep -qx "$AC_RATE"; then target="$AC_RATE"; else target="$(echo "$rates" | tail -1)"; fi
        [ -z "$target" ] && target="$AC_RATE"
        swaymsg output "$MONITOR" mode "${res}@${target}Hz" >/dev/null 2>&1
        log "AC: set $res @ ${target}Hz"
        notify-send -r 999 "Power Manager" "AC: $res @ ${target}Hz"
    else
        # --- ON BATTERY ---
        if echo "$rates" | grep -qx "$BAT_RATE"; then target="$BAT_RATE"; else target="$(echo "$rates" | head -1)"; fi
        [ -z "$target" ] && target="$BAT_RATE"
        swaymsg output "$MONITOR" mode "${res}@${target}Hz" >/dev/null 2>&1
        log "Battery: set $res @ ${target}Hz"
        notify-send -r 999 "Power Manager" "Battery: $res @ ${target}Hz"
    fi
}

# Run once on startup
CURRENT_STATUS=$(cat "$AC_PATH")
apply_power_settings "$CURRENT_STATUS"
echo "$CURRENT_STATUS" >"$STATE_FILE"

# Watch for AC changes (polling method)
while true; do
    sleep 10
    CURRENT_STATUS=$(cat "$AC_PATH")
    LAST_STATUS=$(cat "$STATE_FILE" 2>/dev/null || echo "none")
    if [ "$CURRENT_STATUS" != "$LAST_STATUS" ]; then
        log "AC status changed: $LAST_STATUS -> $CURRENT_STATUS"
        apply_power_settings "$CURRENT_STATUS"
        echo "$CURRENT_STATUS" >"$STATE_FILE"
    fi
done
