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

apply() {
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
    [ "$new" = "$cur" ] && return 0

    if "$PACTL" set-default-source "$new" >/dev/null 2>&1; then
        log "sink $sink -> default source $cur => $new"
    else
        log "failed to set default source $new (sink $sink)"
    fi
}

apply

# Re-evaluate whenever output devices, their cards, or the server default change.
"$PACTL" subscribe 2>/dev/null | while read -r line; do
    case $line in
        *" on sink"* | *" on card"* | *" on server"*) apply ;;
    esac
done
