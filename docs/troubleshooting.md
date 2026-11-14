# Troubleshooting and "why is this weird"

The reasoning lives in the file that implements it. This page is the index by
*symptom*, because several of the odd-looking choices here exist to fix a bug
that is not obvious from the outside.

## The bar

**The bar is waybar, not swaybar.** `files/sway/config` deliberately has no
`bar { }` block; adding one makes sway spawn swaybar next to waybar. waybar is
used because swaybar's tray only forwards `StatusNotifierItem` method calls and
never renders a menu - it has no `com.canonical.dbusmenu` implementation
(`// TODO menu` in `swaybar/tray/item.c`), so right-click did nothing for
blueman, nm-applet and Proton VPN.

**Tray icon shows the red "image-missing" face.** gdk-pixbuf needs a loader cache
that covers SVG. `modules/home/identity.nix` generates one from every loader
directory in the closure (`GDK_PIXBUF_MODULE_FILE`). Pointing it at librsvg's
cache only worked by accident, because gdk-pixbuf compiles png/jpeg in.

**A tray icon disappears after a bar restart.** Proton VPN registers its tray
item once at startup and never re-registers when the
`StatusNotifierWatcher` goes away; restart the app. Other icons re-register.

**`custom/mic`, `custom/audio`, `custom/weather` are empty.** They run
`~/.config/scripts/{mic_status,current-audio,weather_daemon}.sh`; run them by
hand. `custom/weather` reads `/tmp/weather.txt`, refreshed by the
`weather-daemon` unit - check `systemctl --user status weather-daemon`.

## Session daemons

Every daemon is a systemd user unit, never an `exec` in the sway config: sway
does not restart a failed `exec` and `swaymsg reload` never re-runs one, so a
crashed daemon stays gone for the session.

```sh
systemctl --user list-units 'waybar' 'dunst' 'nm-applet' 'blueman-applet' \
  'polkit-gnome*' 'power-manager' 'weather-daemon' 'audio-follow-output' \
  'swayidle' 'sway-audio-idle-inhibit'
```

**GUI privilege prompts never appear** (mounting disks, fwupd, `pkexec` apps) -
that was the polkit agent. `polkit_gnome` ships only an `etc/xdg/autostart` entry
and sway does not implement the XDG autostart spec, so
`polkit-gnome-authentication-agent-1.service` starts it explicitly.

**A unit runs but its script fails to find a command.** User units do not inherit
the login PATH reliably, and home-manager's own `swayidle` unit hardcodes a PATH
containing *bash only* (swayidle wraps commands in `sh -c`). Every unit that runs
a script therefore sets `Environment = "PATH=..."`, using
`config.home.profileDirectory` for the managed packages. See
`modules/home/sway.nix` (`sessionUnit`), `power.nix`, `audio.nix`, `webcam.nix`.

## Idle, lock, blank, hibernate

```sh
journalctl --user -u swayidle -b    # what fired, and when
loginctl show-session "$XDG_SESSION_ID" -p LockedHint
systemctl --user is-active swayidle-lock-on-battery
```

- swayidle's timeouts are static, so each one starts a unit carrying
  `ConditionACPower`; systemd decides whether it applies. Starting the unit for
  the other power source is a skip, not an error.

  | | lock | blank | hibernate |
  |---|---|---|---|
  | battery | 10 min | 10.5 min | 15 min |
  | AC | 2 h | 2 h 30 s | never |

- **The screen locked while I was on battery** is that table, not a bug. The
  journal shows `Started swayidle-lock-on-battery.service` at the idle mark.
- **Nothing hibernates on AC.** `hibernate-on-battery.service` and the battery
  units carry `ConditionACPower=false`; the lid path uses plain `suspend` on AC.
- **Lid close** is `suspend-then-hibernate` on battery and `suspend` on AC
  (`services.logind.settings`, `HibernateDelaySec=1h`). This panel only offers
  `s2idle` (`/sys/power/mem_sleep`), so a shut lid would otherwise drain.
- **Hibernation does not resume.** It needs swap >= RAM (`/dev/pool/swap`, 16 G
  vs 13 GiB) and `resume=` on the kernel command line; both come from
  `nixos/disko-labanos.nix`.

## Audio

**The microphone went live on its own.** `audio-follow-output.service` keeps the
default source on the same `device.id` as the default sink, and it clears a mute
that WirePlumber restored after a reconnect - otherwise calls capture silence.
It only does that when a device appears/disappears or the default output changes.
Volume and mute changes are `Event 'change' on sink`, which it explicitly does
*not* treat as a device event, so a deliberate `Shift+F1` mute survives them.

**Keys:** `Fn+F1` toggles the speaker mute (`XF86AudioMute`), `Shift+F1` the
microphone, `F12` cycles output devices (`files/scripts/cycle-audio.sh`).
`$mod+F12` is free.

**Crackling or a pop after idle.** `snd_hda_intel.power_save=0` and the PipeWire
quantum settings in `nixos/labanos.nix` exist for the ALC295; do not "fix" them
back to defaults.

## Wireless

**WiFi reconnects every ~31 minutes.** The AP publishes a 6 GHz BSSID for the
same SSID that always fails WPA-PSK auth (WPA3-SAE, malformed IEs), and
wpa_supplicant reconsiders it every 1800 s. The profile is pinned to
`band = "a"` for that reason.

## Access and secrets

**Nothing can SSH in.** `services.openssh.enable = false`; tcp/22 is closed. The
*client* is still installed for git remotes. Recovery is physical.

**A rebuild warns about `/etc/nixos-secrets`.** That directory holds the WiFi PSK
and the password hash, which are deliberately not in the store (a store path is
world-readable). See [nixos/README.md](../nixos/README.md) - a missing file does
not fail the switch, it `passwd`s / `nmcli`s its way back.

**The keyring asks to be created on every Proton VPN launch.** It needs
`org.freedesktop.secrets`; `services.gnome.gnome-keyring.enable` provides it, and
because `ly` has its own PAM stack the pam_gnome_keyring rules are mirrored into
`security.pam.services.ly.rules`.

## Apps

**Brave reports "managed by your organization".** That is
`environment.etc."brave/policies/managed/debloat.json"` (Rewards, Wallet, VPN,
News, Talk, Leo, Tor, P3A off).

**Brave/Discord web shows black video or a grey page.** The wrapper args in
`modules/home/packages.nix` disable `AcceleratedVideoEncoder` and
`AcceleratedVideoDecodeLinuxGL` on purpose; the comment there explains which
Chromium switch currently wins.

**`Fontconfig error: Cannot load default config file`** in the journal comes from
`cat` helper processes spawned by Brave's wrapper, not from this configuration.

**RuneScape 3 needs an old OpenSSL.** The native client links OpenSSL 1.1, so
`openssl_1_1` is sourced from a pinned nixpkgs-23.11 and put on
`LD_LIBRARY_PATH` for the client only. `nixos/README.md` records the exact
three-line revert if you ever drop RS3.

**Emacs config changes do not appear.** It is tangled from
`github:prawnfarmerdev/emacsorg` at build time: push, then
`nix flake update emacsorg && home-manager switch`.

## Nix itself

**`~/.nix-profile` is not the Home Manager profile** on this host: it points at
your `nix profile` generations, while the managed packages live in
`/etc/profiles/per-user/<user>` (`config.home.profileDirectory`). Anything ever
`nix profile install`ed shadows managed packages on PATH.

**Disk fills up with generations.** The weekly `nix-gc` service keeps the five
newest system and Home Manager generations plus `nix profile` history younger
than 30 days, then collects garbage. The boot menu shows the same five.
