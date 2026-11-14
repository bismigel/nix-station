#!/bin/sh
# Keep the default *input* on the same hardware as the current *output*.
#
# Why: the noise-cancelling microphone belongs to a headset, so playing audio to
# the headset while recording from the internal mic loses that hardware. Neither
# PipeWire nor WirePlumber links these automatically, so watch for changes and
# point the default source at the input of the same device as the default sink.
#
# The device relation comes from PipeWire's own `device.id` (a sink and its mic
# share one device), which is why this works for ALSA, USB and Bluetooth alike
# without hardcoding names. A name-based fallback covers a missing pw-dump.
#
# Switching the source is not enough on its own: WirePlumber persists mute and
# volume per route and restores them on every reconnect, so the headset came back
# at mute:true / 21% and the call captured silence. gain_floor() clears that.
set -u

resolve() {
    if command -v "$1" >/dev/null 2>&1; then
        command -v "$1"
        return 0
    fi
    for p in "/etc/profiles/per-user/$(id -un)/bin/$1" "/run/current-system/sw/bin/$1"; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

PACTL=$(resolve pactl) || exit 1
PWDUMP=$(resolve pw-dump) || true
JQ=$(resolve jq) || true

LOG=${XDG_RUNTIME_DIR:-/tmp}/audio-follow.log
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

# Input node belonging to the same PipeWire device as the given sink.
source_for_sink() {
    [ -n "${PWDUMP:-}" ] && [ -n "${JQ:-}" ] || return 1
    "$PWDUMP" 2>/dev/null | "$JQ" -r --arg s "$1" '
      (map(select(.type == "PipeWire:Interface:Node"
                  and .info.props["node.name"] == $s))
       | .[0].info.props["device.id"]) as $d
      | select($d != null and $d != "")
      | map(select(.type == "PipeWire:Interface:Node"
                   and .info.props["media.class"] == "Audio/Source"
                   and .info.props["device.id"] == $d))
      | (.[0].info.props["node.name"] // empty)' 2>/dev/null
}

# alsa_output.FOO -> alsa_input.FOO ; bluez_output.MAC.N -> bluez_input.MAC
source_name_for_sink() {
    case $1 in
        bluez_output.*)
            echo "$1" | sed -E 's/^bluez_output\.([0-9A-Fa-f:]+)(\.[0-9]+)?$/bluez_input.\1/'
            ;;
        *output.*)
            echo "$1" | sed 's/output/input/'
            ;;
    esac
}

source_exists() {
    "$PACTL" list short sources 2>/dev/null | awk '{print $2}' | grep -qx "$1"
}

# Clear a restored mute and lift an unusably low level on the source we just
# picked. The mute is the real bug; the level is only lifted when it is so low
# that speech cannot survive it, because 100% is not a safe default on this codec
# (ALC295 capture saturates around 40% node volume - the noise floor goes from
# -38 dBFS at 27% to clipping at 60%) and 27%, the internal array's own resting
# level, is correct. This is not a place to overrule a level the user chose.
# Trade-off: a mute set by hand (Shift+F1) survives until the next device event
# (a sink/card appearing, disappearing, or the default output changing), at which
# point this re-asserts an open microphone.
gain_floor() {
    src=$1
    if [ "$("$PACTL" get-source-mute "$src" 2>/dev/null | awk '{print $2}')" = yes ]; then
        "$PACTL" set-source-mute "$src" 0 >/dev/null 2>&1 && log "unmuted $src"
    fi
    vol=$("$PACTL" get-source-volume "$src" 2>/dev/null | awk '/^Volume:/{print $5}' | tr -d '%')
    case $vol in
        '' | *[!0-9]*) return 0 ;;
    esac
    if [ "$vol" -lt 15 ]; then
        "$PACTL" set-source-volume "$src" 50% >/dev/null 2>&1 &&
            log "raised $src volume $vol% -> 50%"
    fi
}

# apply [lift-mute]
#
# Routing always runs: whichever device the sound is on, the microphone follows.
# Lifting a muted source is separable, because `pactl` reports volume and mute
# changes as `Event 'change' on sink` / `on card` - indistinguishable from the
# events a real device change produces. So the gain floor is only applied when
# the event actually means "a device appeared, disappeared, or the default
# output changed"; a plain 'change' re-routes without touching the mute, which is
# what keeps a deliberate Shift+F1 mute from being undone by a volume key.
apply() {
    lift=${1:-yes}
    sink=$("$PACTL" get-default-sink 2>/dev/null) || return 0
    [ -n "$sink" ] || return 0
    cur=$("$PACTL" get-default-source 2>/dev/null)

    new=$(source_for_sink "$sink")
    if [ -z "$new" ]; then
        candidate=$(source_name_for_sink "$sink")
        if [ -n "$candidate" ] && source_exists "$candidate"; then
            new=$candidate
        fi
    fi

    if [ -z "$new" ]; then
        log "no input on the same device as sink $sink; leaving $cur"
        return 0
    fi
    # Also runs when the source is already default: a reconnect restores the
    # route's mute without changing the default, which is the case that bit us.
    if [ "$new" = "$cur" ]; then
        [ "$lift" = yes ] && gain_floor "$new"
        return 0
    fi

    if "$PACTL" set-default-source "$new" >/dev/null 2>&1; then
        log "sink $sink -> default source $cur => $new"
        [ "$lift" = yes ] && gain_floor "$new"
    else
        log "failed to set default source $new (sink $sink)"
    fi
}

apply

# Re-evaluate on every sink/card/server event, but only lift a muted source when
# the event can mean a device appeared, disappeared, or the default output
# changed. Volume and mute changes emit 'change' on sink *and* on card, so that
# case re-routes silently.
"$PACTL" subscribe 2>/dev/null | while read -r line; do
    case $line in
        *"'new' on sink"* | *"'remove' on sink"* | \
            *"'new' on card"* | *"'remove' on card"* | \
            *"'change' on server"*)
            apply yes
            ;;
        *"'change' on sink"* | *"'change' on card"*)
            apply no
            ;;
    esac
done
