#!/bin/sh
# Run an idle action only when the machine is on AC (or only on battery).
#
# swayidle's timeouts are static, but the wanted schedule depends on the power
# source: on AC the session should stay unlocked for two hours, while on battery
# it hibernates after 10 minutes and locks shortly after as a fallback. Running
# two swayidle instances would double-fire, so every timeout is registered
# unconditionally and this guard decides whether that timeout applies right now.
#
# usage: idle-power-guard.sh <on-ac|on-battery> <lock|dpms-off>
set -u

want_source=${1:-}
action=${2:-}

# Same AC discovery as power-manager.sh, so both agree on what "plugged in" is.
AC_PATH=""
for _ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ACAD/online; do
    if [ -f "$_ac" ]; then
        AC_PATH=$_ac
        break
    fi
done
# No AC node at all (desktop/no battery): treat as permanently on AC.
[ -n "$AC_PATH" ] || AC_PATH=/dev/null

on_ac() {
    [ "$AC_PATH" = /dev/null ] && return 0
    [ "$(cat "$AC_PATH" 2>/dev/null)" = 1 ]
}

case $want_source in
    on-ac)
        on_ac || exit 0
        ;;
    on-battery)
        on_ac && exit 0
        ;;
    *)
        echo "idle-power-guard: bad source '$want_source'" >&2
        exit 1
        ;;
esac

# Resolve helpers even if the unit's PATH is minimal.
resolve() {
    if command -v "$1" >/dev/null 2>&1; then
        command -v "$1"
        return 0
    fi
    for _p in "/etc/profiles/per-user/$(id -un)/bin/$1" "/run/current-system/sw/bin/$1"; do
        if [ -x "$_p" ]; then
            echo "$_p"
            return 0
        fi
    done
    return 1
}

case $action in
    lock)
        swaylock=$(resolve swaylock) || exit 0
        exec "$swaylock" -f
        ;;
    dpms-off)
        swaymsg=$(resolve swaymsg) || exit 0
        exec "$swaymsg" 'output * dpms off'
        ;;
    *)
        echo "idle-power-guard: bad action '$action'" >&2
        exit 1
        ;;
esac
