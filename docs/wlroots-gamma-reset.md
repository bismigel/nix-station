# backend/drm: resetting the colour transform aborts the commit on CRTCs without a gamma LUT

**Project:** wlroots 0.20.2 (sway 1.12)
**Symptom:** once an output has been disabled (`output * dpms off` / `output power off`), it never comes back: `output * dpms on` reports success, `wlr_output` stays disabled, and sway logs `Backend commit failed` with no further detail. On a single-output machine that means the panel is dead until the compositor is restarted.

## Steps to reproduce

Any DRM driver whose CRTCs expose neither a `gamma_lut` property nor a legacy gamma size — reproduced with `virtio-gpu` (qemu `virtio-vga-gl`) and with `bochs-drm`, on NixOS 26.11, kernel 6.18.62, mesa 26.2.6, sway 1.12, wlroots 0.20.2.

```sh
swaymsg 'output * dpms off'          # success, panel off
swaymsg 'output * dpms on'           # reports success...
swaymsg -t get_outputs | grep dpms   # ...but dpms stays false, forever
grim -o <output> /tmp/x.png          # "failed to copy output" — output is gone
```

Journal (sway, `-d`):

```
[INFO]  [sway/commands/output/dpms.c:5] The "output dpms" command is deprecated, use "output power" instead
[DEBUG] [sway/config/output.c:1008] Committing 1 outputs
[DEBUG] [wlr] [types/wlr_output_swapchain_manager.c:185] Test commit for 1 outputs succeeded
[ERROR] [sway/config/output.c:1068] Backend commit failed
```

No kernel error, no `Atomic commit failed` — the ioctl is never issued.

## Root cause

`sway`/`wlr_scene_output_build_state()` always commits `WLR_OUTPUT_STATE_COLOR_TRANSFORM`, with `color_transform == NULL` when no transform is in use. In `drm_atomic_connector_prepare()` (`backend/drm/atomic.c`):

```c
	if (state->base->committed & WLR_OUTPUT_STATE_COLOR_TRANSFORM) {
		size_t dim = 0;
		uint16_t *lut = NULL;
		if (state->base->color_transform != NULL) { ... }
		if (crtc->props.gamma_lut == 0) {
			if (!drm_legacy_crtc_set_gamma(drm, crtc, dim, lut)) {
				return false;
			}
		}
```

so the "reset to identity" case (`dim == 0`) goes to `drm_legacy_crtc_set_gamma()` in `backend/drm/legacy.c`, which asks the CRTC how large its gamma LUT is — and for a CRTC without gamma support that is 0:

```c
	if (size == 0) {
		// The legacy interface doesn't offer a way to reset the gamma LUT
		size = drm_crtc_get_gamma_lut_size(drm, crtc);
		if (size == 0) {
			return false;            // <-- identity transform treated as failure
		}
```

That `false` propagates out of `drm_atomic_connector_prepare()`, and `atomic_device_commit()` then takes a `goto out` that logs nothing:

```c
	for (size_t i = 0; i < state->connectors_len; i++) {
		if (!drm_atomic_connector_prepare(&state->connectors[i], state->modeset)) {
			goto out;                // <-- the only trace is sway's "Backend commit failed"
		}
	}
```

So the whole atomic commit is aborted, the connector never gets re-enabled, and nothing in the log says why.

Confirming trace from a build with temporary logging at every `return false` in the path:

```
DBG: wlr_backend_commit n=1 has_impl=1
DBG: multi commit sub=… len=1 test=0
DBG: commit_drm_device n=1 test=0 active=1
DBG: atomic_conn_prepare active=1 modeset=1 wait_tl=0x…520 committed=0x1dbf
DBG: legacy gamma failed
DBG: drm_commit returned ok=0
DBG: impl->commit returned false
```

(The swapchain manager's test commit succeeds because it does not include the colour-transform field; only sway's real commit does.)

## Patch

Two changes: resetting to the identity transform is a no-op success when the CRTC has no gamma LUT at all, and the atomic commit path says why it gave up.

```diff
--- a/backend/drm/legacy.c
+++ b/backend/drm/legacy.c
@@ -255,7 +255,9 @@
 		// The legacy interface doesn't offer a way to reset the gamma LUT
 		size = drm_crtc_get_gamma_lut_size(drm, crtc);
 		if (size == 0) {
-			return false;
+			// The CRTC has no gamma LUT at all (e.g. virtio-gpu), so the
+			// identity transform is already in effect: nothing to reset.
+			return true;
 		}
--- a/backend/drm/atomic.c
+++ b/backend/drm/atomic.c
@@ -574,6 +574,8 @@
 	for (size_t i = 0; i < state->connectors_len; i++) {
 		if (!drm_atomic_connector_prepare(&state->connectors[i], state->modeset)) {
+			wlr_drm_conn_log(state->connectors[i].connector, WLR_ERROR,
+				"Failed to prepare connector for atomic commit");
 			goto out;
 		}
 	}
```

## Verification

Rebuilt wlroots 0.20.2 with the patch and re-ran the same sequence in the same VM:

```
before=[true]   off=[false]   on=[true]
grim: 809747-byte capture of live content
journal: 0 occurrences of "Backend commit failed", no errors
```

Unpatched, the same sequence ends at `on=[false]` with `Backend commit failed`.

## Notes

* amdgpu is not affected through this path: its CRTCs expose `gamma_lut`, so the atomic blob path is taken and `create_gamma_lut_blob(size = 0)` correctly produces blob 0.
* A separate, still-unexplained observation on amdgpu hardware (Radeon 780M, eDP): after `output * dpms off` → `output * dpms on` the output *does* come back and commits succeed, but the panel showed a uniform `#ff0000` frame with only the hardware cursor live, and screencopy returned a byte-identical uniform red image for two different workspace contents. That is a rendering-path defect, not this commit-abort bug, and it did not reproduce in the VM (pixman, llvmpipe and virgl all render correctly once the commit succeeds).
