{
  config,
  inputs,
  lib,
  ...
}:
let
  pkgs = config.station.pkgs;
  inherit (pkgs.stdenv.hostPlatform) system;

  # RuneScape 3's native Linux client (used by Bolt) needs OpenSSL 1.1, which
  # nixpkgs removed as end-of-life, so source it from the pinned older nixpkgs.
  pkgsOld = import inputs.nixpkgs-old {
    inherit system;
    config.permittedInsecurePackages = [ "openssl-1.1.1w" ];
  };
  openssl11 = pkgsOld.openssl_1_1;

  # nixpkgs' bolt-launcher leaves out GTK2 (needed by the RS3 client) unless
  # enableRS3 is set, and never provides OpenSSL 1.1. Wrap it so the sandboxed
  # client finds both.
  boltPkg = pkgs.bolt-launcher.override { enableRS3 = true; };

  boltLauncher = pkgs.writeShellScriptBin "bolt-launcher" ''
    export LD_LIBRARY_PATH="${lib.getLib openssl11}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec ${boltPkg}/bin/bolt-launcher "$@"
  '';

  # sway cannot render absolute-path StatusNotifierItem IconName values.
  # swaybar/tray/icon.c has no '/' special case: it concatenates the whole path
  # into every theme candidate, e.g.
  #   ~/.icons/hicolor/128x128@2/actions//nix/store/.../state-disconnected.svg.png
  # which can never exist, so it falls back to the red "image-missing" face.
  #
  # Proton VPN points IconName at an absolute asset path
  # (tray_indicator.py ICON constants), so under sway its tray icon can never
  # resolve. Rewrite those three constants to plain theme icon names and ship
  # matching icons, so the normal theme lookup succeeds.
  #
  # (blueman needs no patch: it already sends a name, and its only icon happened
  # to be an SVG - that was purely the missing GDK_PIXBUF_MODULE_FILE in
  # identity.nix.)
  protonVpnTray = pkgs.proton-vpn.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      tray=proton/vpn/app/gtk/widgets/main/tray_indicator.py
      if [ -f "$tray" ]; then
        substituteInPlace "$tray" \
          --replace 'ICONS_PATH / f"state-{states.Disconnected.__name__.lower()}.svg"' \
                    'f"proton-vpn-tray-{states.Disconnected.__name__.lower()}"' \
          --replace 'ICONS_PATH / f"state-{states.Connected.__name__.lower()}.svg"' \
                    'f"proton-vpn-tray-{states.Connected.__name__.lower()}"' \
          --replace 'ICONS_PATH / f"state-{states.Error.__name__.lower()}.svg"' \
                    'f"proton-vpn-tray-{states.Error.__name__.lower()}"'
      else
        echo "WARNING: $tray not found - Proton tray icon patch did not apply" >&2
      fi
    '';
  });

  # The icons the patched app now asks for, in the theme dirs swaybar sweeps.
  protonVpnTrayIcons = pkgs.runCommand "proton-vpn-tray-icons" { } ''
    assets=$(echo ${protonVpnTray}/lib/python*/site-packages/proton/vpn/app/gtk/assets/icons)
    for s in disconnected connected error; do
      mkdir -p "$out/share/icons/hicolor/scalable/apps"
      cp "$assets/state-$s.svg" \
         "$out/share/icons/hicolor/scalable/apps/proton-vpn-tray-$s.svg"
    done
  '';

  # Apps that need unfree (Steam, Zoom) or are large.
  graphical = with pkgs; [
    # Browsers.
    # Brave: the nixpkgs wrapper force-enables VA-API
    # (--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder)
    # and carries its own --disable-features list. Chromium keeps the *last*
    # value of a repeated switch, so an override that only names what it wants
    # to drop silently resurrects OutdatedBuildDetector and
    # UseChromeOSDirectVideoDecoder - hence the full restatement below.
    #
    # Why each entry is off:
    #  - AcceleratedVideoEncoder: makes WebRTC send black frames on this AMD
    #    laptop (the local preview still looks fine).
    #  - AcceleratedVideoDecodeLinuxGL: the Wayland GL-backed VA-API path crashes
    #    renderers here, which is what turns Discord web grey / "render process
    #    gone". Drop this entry first if you want hardware decode back.
    (brave.override {
      commandLineArgs = "--disable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,OutdatedBuildDetector,UseChromeOSDirectVideoDecoder";
    })
    firefox
    chromium

    # Communication
    vesktop
    zoom-us
    protonVpnTray
    protonVpnTrayIcons
    localsend

    # Media / downloads
    mpv
    qbittorrent
    deluge
    foliate

    # Gaming (steam is provided by programs.steam.enable on NixOS)
    gamescope
    # RuneScape launcher (supports RS3 and OSRS); nixpkgs removed the old
    # `runescape` package and points here instead. See `boltLauncher` above.
    boltLauncher
  ];

  # Nerd Fonts are provided as an attribute set in nixpkgs.
  fonts = with pkgs.nerd-fonts; [
    inconsolata
    lekton
    symbols-only
  ];
in
{
  config.station.home =
    { ... }:
    {
      home.packages =
        with pkgs;
        [
          # ---- Wayland compositor / desktop shell ----
          sway
          swayidle
          swaylock
          swaybg
          grim
          slurp
          wl-clipboard
          wtype
          sway-audio-idle-inhibit
          i3status
          rofi
          dunst
          libnotify
          networkmanagerapplet
          polkit_gnome
          gnome-keyring
          xdg-utils
          xdg-desktop-portal
          xdg-desktop-portal-gtk

          # ---- Input / power / audio ----
          libinput
          brightnessctl
          playerctl
          upower
          tlp
          powertop
          pipewire
          wireplumber
          pulseaudio
          pavucontrol
          alsa-utils

          # ---- Session bus / system helpers ----
          dbus
          util-linux
          networkmanager
          polkit

          # ---- Bluetooth ----
          # Terminal UI for pairing/connecting devices, the nmtui analogue to
          # blueman-manager (which needs a graphical session). Bound to
          # $mod+Ctrl+b in files/sway/config.
          bluetui

          # ---- Terminals / editors ----
          ghostty
          xterm
          emacs-pgtk
          neovim

          # ---- CLI / dev tooling ----
          git
          gh
          gnumake
          jq
          curl
          wget
          openssl
          sshpass
            kubernetes
            kubernetes-helm
            argocd
            k9s
            kubectx
            opentofu
            yq

            # ---- Server and disk diagnostics ----
            btrfs-progs
            smartmontools
            nvme-cli
            lm_sensors
            parted
            gptfdisk

            # ---- Homelab secrets / backup / context ----
            sops
            age
            rclone
            rsync
            bitwarden-cli
            bws

            tmux
            opencode
            pi-coding-agent
            herdr
            btop
          htop
          fastfetch
          cmatrix
          yazi
          ripgrep
          fd
          fzf
          file
          unzip
          p7zip

          # ---- Webcam ----
          v4l-utils

          # ---- Theming / fonts ----
          gtk3
          gtk4
          # Bar (replaces swaybar; see files/sway/config + files/waybar/)
          waybar
          adwaita-icon-theme
          papirus-icon-theme
          liberation_ttf
          dejavu_fonts
          noto-fonts
          noto-fonts-color-emoji
        ]
        ++ fonts
        ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 graphical;

      # Wrapping bolt-launcher (above) drops the .desktop file the package ships,
      # so recreate it and its icon here to keep it searchable in rofi.
      xdg.desktopEntries."bolt-launcher" = {
        name = "Bolt Launcher";
        genericName = "RuneScape";
        comment = "Alternative launcher for RuneScape (RS3 and OSRS)";
        exec = "bolt-launcher";
        icon = "bolt-launcher";
        terminal = false;
        categories = [ "Game" ];
        settings = {
          StartupWMClass = "BoltLauncher";
          Keywords = "RuneScape;RS3;OSRS;Bolt;MMO;";
        };
      };

      xdg.dataFile."icons/hicolor/256x256/apps/bolt-launcher.png".source =
        "${boltPkg}/share/icons/hicolor/256x256/apps/bolt-launcher.png";
    };
}
