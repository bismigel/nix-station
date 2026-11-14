#!/usr/bin/env bash
# Re-apply the laptop webcam's white balance.
#
# The "USB2.0 HD UVC WebCam" occasionally initialises its auto white balance to
# a warm/yellow calibration, which leaves the preview tinted. Toggling
# white_balance_automatic off and back on makes the camera recalculate it
# against the current room light. Run manually or from the systemd path unit.
set -euo pipefail

command -v v4l2-ctl >/dev/null 2>&1 || exit 0

DEV="${WEBCAM_DEVICE:-}"
if [ -z "$DEV" ]; then
    # Find the camera's capture node by name instead of assuming /dev/video0.
    # The UVC device exposes video0/video1/media0, and the numbering is not
    # stable across suspend/resume and re-enumeration. v4l2-ctl --list-devices
    # prints "<name> (bus):" and then one indented node per line, the first
    # being the capture device.
    DEV=$(v4l2-ctl --list-devices 2>/dev/null | awk '
        /^[^ \t]/ { matched = ($0 ~ /[Cc]amera|[Ww]eb[Cc]am|UVC/) ; next }
        matched && /\/dev\/video/ { gsub(/[ \t]/, "", $1); print $1; exit }')
fi
DEV="${DEV:-/dev/video0}"

[ -e "$DEV" ] || exit 0

for _ in 1 2 3 4 5; do
  if v4l2-ctl -d "$DEV" --set-ctrl=white_balance_automatic=0 >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

v4l2-ctl -d "$DEV" --set-ctrl=white_balance_automatic=1 >/dev/null 2>&1 || true
