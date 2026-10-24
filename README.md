# nix-station

Declarative reproduction of this ASUS ROG Zephyrus G14 laptop's desktop, built
on [Home Manager](https://github.com/nix-community/home-manager). It installs
the apps and manages the dotfiles for a **Sway / Wayland** desktop, and it works
on any Linux distribution that has Nix installed, as well as on NixOS.

The reference machine: ASUS ROG Zephyrus G14 (GA402RK), AMD Ryzen 9 6900HS
(Radeon 680M), Sway + i3status on Wayland. The owner is `okra`, hostname
`nixos`.

## Layout

```
flake.nix                  # inputs + dendritic entry point (mkFlake + import-tree)
modules/
  base.nix                 # flake systems, station.pkgs, the station.home option
  formatter.nix            # nixfmt
  home-configurations.nix  # flake.homeConfigurations + published flake.homeModules
  home/
    identity.nix           # username/homeDirectory options, session vars, cursor
    packages.nix           # every application / CLI / font
    sway.nix               # Sway, swaylock, i3status config
    power.nix              # swayidle + battery-only hibernate
    webcam.nix             # webcam white-balance reset at login
    desktop.nix            # dunst, rofi, ghostty, btop, GTK settings
    emacs.nix              # literate Emacs config (tangled from emacsorg)
    shell.nix              # bash (prompt, aliases, PATH)
    scripts.nix            # ~/.config/scripts and ~/.local/bin helpers
files/                     # the actual config files (tracked, portable)
```

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

All paths inside `files/` use `~` / `$HOME`, so the repo works for a user other
than `okra`.

> **Flakes only see git-tracked files.** After adding a new `modules/**/*.nix`
> file, `git add` it before running any `nix` command, or the file is silently
> left out of the build.

## What gets installed

- **Desktop / WM:** Sway (swayidle, swaylock, swaybg), grim, slurp, wl-clipboard,
  wtype, i3status, rofi, dunst, network-manager-applet, polkit-gnome,
  gnome-keyring
- **Browsers:** Brave, Firefox, Chromium
- **Comms:** Vesktop, Zoom, Proton VPN
- **Media:** mpv, qBittorrent, Deluge
- **Gaming:** Steam, gamescope
- **Terminals / editors:** Ghostty, xterm, Emacs, Neovim
- **CLI:** git, gh, jq, curl, wget, kubernetes, helm, tmux, btop, htop,
  fastfetch, cmatrix, yazi, ripgrep, fd, fzf, ...
- **Audio / input / power:** pipewire, wireplumber, pulseaudio, pavucontrol,
  playerctl, brightnessctl, tlp, powertop, upower, v4l-utils
- **Fonts:** Inconsolata, Lekton and Symbols Nerd Fonts, Liberation, DejaVu,
  Noto.

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

3. **Add the host** to `config.station.hosts` in `modules/base.nix` (hostname
   → username). `nixos` and `labanos` are already defined. Every host gets the
   same merged home module; only the username and home directory differ.

4. **Activate Home Manager.**

   ```sh
   nix run home-manager/master -- switch --flake .#nixos
   ```

   The flake attribute is the host name from `station.hosts` (e.g. `.#nixos`,
   `.#labanos`).

5. **Start the desktop.**

   Log in through your display manager and pick the **Sway** session (on this
   machine the `ly` greeter defaults to it).

## Day-to-day

```sh
home-manager switch --flake ~/projects/nix-station#nixos   # apply changes
home-manager generations                                      # rollback list
nix flake update                                              # bump inputs
```

## Migration caveats

Home Manager refuses to overwrite files it does not already manage. When
switching on a machine that already has these dotfiles, back them up first:

```sh
home-manager switch --flake .#nixos -b backup
```

or remove the old files (`~/.config/sway`, `~/.config/i3status`,
`~/.config/rofi`, `~/.config/dunst`, `~/.config/scripts`, `~/.local/bin`,
`~/.bashrc`, ...) before the first switch.

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
- The bar reads `/tmp/{weather,audio_output,mic_status}.txt`, written by the
  daemons under `~/.config/i3status/scripts/`.
- **Emacs** uses the literate config from
  [`prawnfarmerdev/emacsorg`](https://github.com/prawnfarmerdev/emacsorg)
  (pinned as the `emacsorg` flake input). `modules/home/emacs.nix` tangles its
  `readme.org` into `~/.emacs.d/{early-init.el,init.el}` plus the Menudo theme
  at `~/.emacs.d/config/theme.el`. Packages are installed on first launch by
  `package.el`; bump the config with `nix flake update emacsorg`.
- **Tree-sitter:** all nixpkgs grammars (`emacsPackages.treesit-grammars.with-all-grammars`)
  are provided and symlinked to `~/.emacs.d/tree-sitter`, so tree-sitter works
  without any runtime grammar compilation.
- `i3status` currently uses a hardware-specific battery path
  (`/sys/class/power_supply/BAT%d/uevent`) and a Toronto timezone; edit
  `files/i3status/config` for other hardware/regions.

## Reusing on NixOS

Add the Home Manager module to a NixOS host:

```nix
{
  inputs.nix-station.url = "github:<you>/nix-station";

  # in the host configuration:
  imports = [ inputs.home-manager.nixosModules.home-manager ];
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
