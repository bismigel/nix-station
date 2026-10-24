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

  # Apps that need unfree (Steam, Zoom) or are large.
  graphical = with pkgs; [
    # Browsers.
    # Brave: the nixpkgs wrapper force-enables VAAPI encode
    # (--enable-features=AcceleratedVideoEncoder). On this AMD laptop that makes
    # WebRTC send black frames (the local preview still looks fine), so disable
    # hardware video encoding while keeping hardware decode.
    (brave.override {
      commandLineArgs = "--disable-features=AcceleratedVideoEncoder";
    })
    firefox
    chromium

    # Communication
    vesktop
    zoom-us
    proton-vpn
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
