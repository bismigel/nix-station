# nix-station

Declarative reproduction of the desktop on my personal Linux machines, built
on [Home Manager](https://github.com/nix-community/home-manager). It installs
the apps and manages the dotfiles for a **Sway / Wayland** desktop, and it works
on any Linux distribution that has Nix installed, as well as on NixOS.

The home configuration is shared by every machine. A host differs by its
hostname and username, both of which live in `config.station.hosts`
(`modules/base.nix`):

| host      | user      | machine                                  | kind |
| --------- | --------- | ---------------------------------------- | ---- |
| `labanos` | `labanos` | Framework Laptop 16 (AMD Ryzen 7040)     | NixOS system config + embedded Home Manager |
| `nixos`   | `okra`    | ASUS ROG Zephyrus G14 (GA402RK)          | standalone Home Manager only |

The genuinely hardware-specific values are few and are kept together (see
[Adding another machine](#adding-another-machine)) so a new PC mostly costs a
hostname and a username. A NixOS host additionally needs its own
`nixos/<host>.nix` (boot, disk layout, services) - only `labanos` has one.

## Layout

```
flake.nix                  # inputs + dendritic entry point (mkFlake + import-tree)
docs/
  troubleshooting.md       # symptom -> cause index for the odd-looking choices
nixos/
  labanos.nix              # the NixOS host: boot, LUKS, networking, audio, power, ly
  disko-labanos.nix        # disk layout (LUKS2 + LVM + btrfs subvolumes)
  README.md                # install / secrets runbook for that host
modules/
  base.nix                 # flake systems, station.pkgs, the station.home option
  formatter.nix            # nixfmt
  home-configurations.nix  # flake.homeConfigurations + published flake.homeModules
  nixos-configurations.nix # flake.nixosConfigurations.labanos
  home/
    identity.nix           # username/homeDirectory options, session vars, cursor
    packages.nix           # every application / CLI / font
    sway.nix               # Sway config + the session systemd units
    power.nix              # swayidle schedule (power-aware), audio idle inhibitor
    audio.nix              # default source follows the default sink
    webcam.nix             # webcam white-balance reset at login
    desktop.nix            # dunst, rofi, ghostty, btop, fastfetch, GTK settings
    emacs.nix              # literate Emacs config (tangled from emacsorg)
    shell.nix              # bash (prompt, aliases, PATH)
    scripts.nix            # ~/.config/scripts and ~/.local/bin helpers
    backup.nix             # nightly age-encrypted admin backup to R2
    deadman.nix            # external dead-man's switch for the homelab edge
files/                     # the actual config files (tracked, portable)
```

If something behaves oddly - a tray icon missing, the screen locking earlier than
expected, a daemon that cannot find a command - start with
[docs/troubleshooting.md](docs/troubleshooting.md): most of the strange-looking
choices in here exist to fix a specific bug, and that page indexes them by
symptom.

### Dendritic pattern

Every `.nix` file under `modules/` is a
[flake-parts](https://flake.parts) module that is auto-imported by
[import-tree](https://github.com/denful/import-tree) - there are no hand-written
`imports` lists, and every file implements one feature.

The top-level configuration owns its own options (`modules/base.nix`,
`modules/home/identity.nix`) instead of piggy-backing on flake-parts internals.
Each feature in `modules/home/` assigns to the single `station.home`
[`deferredModule`](https://nixos.org/manual/nixos/stable/#sec-option-types-submodule)
option; the module system merges the assignments automatically:

```nix
{ config, ... }:
{
  config.station.home = { pkgs, ... }: {
    # home-manager config for this feature
  };
}
```

Adding a feature is therefore just adding a file - pick any path/name and it
joins the configuration. Lower-level values the feature needs (`inputs`,
`pkgs`, identity) are read from the top-level `config` and closed over, so
nothing is threaded through `extraSpecialArgs`. `modules/home-configurations.nix`
pulls the merged module into `flake.homeConfigurations` and publishes it as
`flake.homeModules.default`.

All paths inside `files/` use `~` / `$HOME`, so the repo works for any username;
nothing assumes `okra` or `labanos`.

> **Flakes only see git-tracked files.** After adding a new `modules/**/*.nix`
> file, `git add` it before running any `nix` command, or the file is silently
> left out of the build.

## What gets installed

- **Desktop / WM:** Sway (swayidle, swaylock, swaybg), grim, slurp, wl-clipboard,
  wtype, waybar, rofi, dunst, network-manager-applet, polkit-gnome (authentication
  agent, run as a session unit), gnome-keyring, sway-audio-idle-inhibit
- **Browsers:** Brave, Firefox, Chromium
- **Comms:** Vesktop, Zoom, Proton VPN
- **Media:** mpv, qBittorrent, Deluge
- **Gaming:** Steam, gamescope
- **Terminals / editors:** Ghostty, xterm, Emacs, Neovim
- **CLI:** git, gh, jq, curl, wget, kubernetes, helm, tmux, btop, htop,
  fastfetch, cmatrix, yazi, ripgrep, fd, fzf, ...
- **Audio / input / power:** PipeWire + WirePlumber, TLP, UPower and polkit run as
  *system* services (on a NixOS host); the user profile only carries the clients
  (pavucontrol, playerctl, brightnessctl, powertop, alsa-utils, v4l-utils).
- **Fonts:** Inconsolata, Lekton and Symbols Nerd Fonts, Liberation, DejaVu,
  Noto.

## Bar and idle behaviour

- **The bar is waybar, not swaybar.** swaybar's tray only forwards clicks as
  StatusNotifierItem method calls and has no `com.canonical.dbusmenu`
  implementation (`// TODO menu` in `swaybar/tray/item.c`), so right-click did
  nothing for blueman, nm-applet and Proton VPN - all three publish their menus
  via dbusmenu. waybar implements it and pops a real menu. `files/waybar/style.css`
  reproduces the old look (black bar, i3 workspace colours, the i3status
  good/degraded/bad palette) and adds threshold colours: battery goes amber at
  15% and red at 5%, with the same treatment for cpu/memory/disk.
- **Idle timeouts depend on the power source.** swayidle's timeouts are static
  and two instances would double-fire, so every branch is registered and each
  timeout starts a small unit (`swayidle-lock-on-{ac,battery}`,
  `swayidle-blank-on-{ac,battery}`, `hibernate-on-battery`) whose
  `ConditionACPower` lets **systemd** pick: the unit for the other power source
  is simply skipped. No shell dispatcher is involved. On AC the session locks
  after **2 hours** and never hibernates; on battery it locks at **10 minutes**,
  blanks 30 s later, and hibernates at **15 minutes**. Locking before hibernating
  means a refused or failed hibernation still leaves a dark, locked screen.
  Blanking dims the backlight (`brightnessctl -s set 0`), never DPMS: see
  `modules/home/power.nix` for why.
  `before-sleep` always locks too, so a lid close locks immediately.
- **Every session daemon is a systemd user unit** (`modules/home/sway.nix`), not
  a sway `exec`: sway does not restart a failed `exec` and `swaymsg reload` never
  re-runs one, so a crashed bar/applet/notification daemon stayed gone for the
  session. `sway-audio-idle-inhibit` was the case that bit: as an `exec` it lost
  the pipewire startup race and the result was no inhibitor at all, so calls and
  video still counted as idle and locked the session mid-use. Check them with
  `systemctl --user list-units 'waybar' 'dunst' 'nm-applet' 'blueman-applet'
  'polkit-gnome*' 'power-manager' 'weather-daemon'`.
- **SVG tray icons need a gdk-pixbuf loader cache** covering both gdk-pixbuf's
  own loaders and librsvg's. `identity.nix` generates that cache; without it the
  tray draws `image-missing` for SVG-only icons such as blueman's.
- Proton VPN registers its tray item once at startup and never re-registers
  when the bar's StatusNotifierWatcher restarts, so its icon disappears after a
  bar restart until the app is restarted.

## Fresh install on another machine

1. **Install Nix** (with flakes enabled).

   ```sh
   sh <(curl -L https://nixos.org/nix/install) --daemon
   # ensure experimental-features includes nix-command flakes in /etc/nix/nix.conf
   ```

2. **Clone this repo.**

   ```sh
   git clone <your-remote> ~/projects/nix-station
   cd ~/projects/nix-station
   ```

3. **Add the host** to `config.station.hosts` in `modules/base.nix` - see
   [Adding another machine](#adding-another-machine). Every host gets the same
   merged home module; only the username and home directory differ.

4. **Activate Home Manager.**

   ```sh
   nix run home-manager/master -- switch --flake .#nixos
   ```

   The flake attribute is the host name from `station.hosts` (e.g. `.#nixos`,
   `.#labanos`).

5. **Start the desktop.**

   Log in through your display manager and pick the **Sway** session (on this
   machine the `ly` greeter defaults to it).

## Adding another machine

A new PC needs a hostname and a username, plus a check of the handful of
values that are genuinely tied to hardware. Nothing else is per-machine.

1. Add the host to `config.station.hosts` in `modules/base.nix`:

   ```nix
   config.station.hosts = {
     nixos.username = "okra";
     labanos.username = "labanos";
     mynewpc.username = "labanos";
   };
   ```

2. Switch with that attribute: `home-manager switch --flake .#mynewpc` (or
   `sudo nixos-rebuild switch --flake .#mynewpc` where the host is a NixOS
   configuration).

3. Check these hardware-specific knobs and adjust if the machine differs:

   | Value | Where | Notes |
   | ----- | ----- | ----- |
   | `bat = "BAT1"` | `files/waybar/config` | battery device name |
   | `AC_RATE` / `BAT_RATE` | `files/scripts/power-manager.sh` | panel refresh rates; falls back to the highest/lowest the panel advertises |
   | `output eDP-1 adaptive_sync on`, `output * scale 2` | `files/sway/config` | output name, HiDPI scale |
   | `$mod` and keybindings | `files/sway/config` | unchanged between my machines |
   | timezone | `files/waybar/config` | currently `America/Toronto` |

The idle schedule needs no per-machine edits: the `swayidle-*-on-{ac,battery}`
units use systemd's `ConditionACPower`, which reads
`/sys/class/power_supply/*/online` itself and treats a machine with no AC node as
permanently plugged in.

## Day-to-day

```sh
home-manager switch --flake ~/projects/nix-station#nixos   # standalone HM host
sudo nixos-rebuild switch --flake .#labanos               # this NixOS host (HM embedded)
home-manager generations                                   # rollback list
nix flake update                                           # bump inputs
```

## Migration caveats

Home Manager refuses to overwrite files it does not already manage. When
switching on a machine that already has these dotfiles, back them up first:

```sh
home-manager switch --flake .#nixos -b backup
```

or remove the old files (`~/.config/sway`, `~/.config/waybar`,
`~/.config/rofi`, `~/.config/dunst`,
`~/.config/scripts`, `~/.local/bin`, `~/.bashrc`, ...) before the first switch.

A few things stay machine/distribution specific and are intentionally **not**
managed here:

- `~/.gitconfig` (contains your credentials helper / identity)
- browser/app profiles (`~/.mozilla`, `~/.config/chromium`, Steam data)
- any Flatpak installs (now replaced by native nixpkgs apps)

## Notes

- **No Flatpak.** Brave, Proton VPN, Vesktop and Zoom are installed from
  nixpkgs; the old Flatpak wrappers were removed so the native binaries win.
- **Steam** is unfree and, on a non-NixOS host, may need extra set-up (the
  `steam` package plus `nixpkgs.config.allowUnfree`, already set here). On NixOS
  prefer `programs.steam.enable = true`.
- The bar is **waybar**; its `custom/{weather,audio,micdev,mic}` modules run
  `files/scripts/{weather_daemon,current-audio,current-mic,mic_status}.sh`
  directly (`custom/weather` reads the `/tmp/weather.txt` the weather unit
  refreshes). Nothing from i3status is used or installed any more.
- **SSH into `labanos` is disabled** on purpose (`services.openssh.enable =
  false`), which also closes tcp/22 in the firewall. The ssh *client* stays
  installed for git remotes. Remote access is via the homelab, not this laptop.
- **Emacs** uses the literate config from
  [`prawnfarmerdev/emacsorg`](https://github.com/prawnfarmerdev/emacsorg)
  (pinned as the `emacsorg` flake input). `modules/home/emacs.nix` tangles its
  `readme.org` into `~/.emacs.d/{early-init.el,init.el}` plus the Menudo theme
  at `~/.emacs.d/config/theme.el`. Packages are installed on first launch by
  `package.el`; bump the config with `nix flake update emacsorg`.
- **Tree-sitter:** all nixpkgs grammars (`emacsPackages.treesit-grammars.with-all-grammars`)
  are provided and symlinked to `~/.emacs.d/tree-sitter`, so tree-sitter works
  without any runtime grammar compilation.
- `files/waybar/config` pins the battery to `bat = "BAT1"` and the clock to
  `America/Toronto`; edit those two for other hardware/regions. `BAT1` is what
  this laptop exposes - there is no `BAT0`, which an i3status-style `BAT%d` glob
  would have silently missed.

## Reusing on NixOS

Add the Home Manager module to a NixOS host:

```nix
{
  inputs.nix-station.url = "github:<you>/nix-station";

  # in the host configuration:
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  # One nixpkgs instance, as modules/nixos-configurations.nix does: the module
  # already closes over `station.pkgs`, so let NixOS use that same instance
  # instead of configuring a second one.
  nixpkgs.pkgs = inputs.nix-station.station.pkgs;  # or your own
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.okra = {
      imports = [ inputs.nix-station.homeModules.default ];
      targets.genericLinux.enable = false;
    };
  };
}
```

No `extraSpecialArgs` are needed: the published module already carries its
`inputs`, `pkgs` and identity, having closed over them at the top level. To reuse
it for a different user, edit the options in `modules/home/identity.nix`.
