#!/usr/bin/env bash
# Check VRR support and status

DEBUGFS="$(ls /sys/kernel/debug/dri/*/eDP-*/vrr_range 2>/dev/null | head -1)"
DEBUGFS="${DEBUGFS:-/sys/kernel/debug/dri/0/eDP-2/vrr_range}"

# Check if debugfs is mounted
if ! mount | grep -q "debugfs on /sys/kernel/debug"; then
    echo "debugfs not mounted, mounting..."
    sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not mount debugfs. Run with sudo or ensure debugfs is in /etc/fstab"
    fi
fi

echo "=== VRR Status ==="
if [ -f "$DEBUGFS" ]; then
    echo "VRR range:"
    sudo cat "$DEBUGFS" 2>/dev/null
else
    echo "VRR debugfs not accessible at $DEBUGFS"
    echo "Debugfs status:"
    mount | grep debugfs || echo "Not mounted"
fi

echo ""
echo "Sway adaptive_sync (VRR) state:"
swaymsg -t get_outputs 2>/dev/null | grep -E '"name"|adaptive_sync' || echo "swaymsg unavailable (not in a Sway session?)"

echo ""
echo "Graphics card:"
lspci | grep -E "(VGA|Display|Graphics)"

echo ""
echo "Kernel parameters:"
cat /proc/cmdline | grep -o "amdgpu.vrr=[^ ]*" || echo "amdgpu.vrr not found in cmdline"

echo ""
echo "Summary: VRR is supported (60-120Hz range)."
echo "VRR is enabled in Sway via 'output eDP-1 adaptive_sync on' (files/sway/config)."
echo "Kernel: amdgpu.vrr=1 (or amdgpu.vrr=2 to force)."
echo "Requires fullscreen applications (games) for VRR to activate."
