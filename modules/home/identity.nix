{
  config,
  lib,
  ...
}:
let
  inherit (config.station.identity) username homeDirectory;
in
{
  options.station.identity = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "okra";
    };
    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.station.identity.username}";
    };
  };

  config.station.home =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home = {
        username = lib.mkDefault username;
        homeDirectory = lib.mkDefault homeDirectory;
        stateVersion = "25.05";
      };

      # Makes Home Manager behave nicely on non-NixOS distributions (Void, Arch,
      # Debian, ...). On a NixOS host you would set this to false from the system
      # configuration instead.
      targets.genericLinux.enable = lib.mkDefault true;

      xdg.enable = true;

      home.sessionPath = [
        "${config.home.homeDirectory}/.local/bin"
        "${config.home.homeDirectory}/.opencode/bin"
      ];

      home.sessionVariables = {
        TERMINAL = "ghostty";
        RADV_PERFTEST = "aco";
        MESA_SHADER_CACHE_DIR = "${config.xdg.cacheHome}/mesa-shaders";

        # Run Wayland-native where possible.
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";

        # gdk-pixbuf needs this to decode SVG. swaybar loads tray icons through
        # gdk-pixbuf; without the loader cache the SVG is opened but cannot be
        # decoded, so sway draws `image-missing` (the red sad face).
        #
        # Symptom this fixes: blueman's StatusNotifierItem requests
        # IconName="blueman-active", whose only icon on this system is
        # hicolor/scalable/status/blueman-active.svg -> unrenderable without
        # this, so the systray showed a sad face. nm-applet only appeared to
        # work because its icon resolves to a PNG (hicolor/22x22/apps).
        # GTK apps started from a terminal inherit this from their wrapper,
        # which is why it appeared set in an interactive shell but not in
        # sway's own environment. See modules/home/packages.nix history.
        GDK_PIXBUF_MODULE_FILE =
          "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
      };

      # Cursor theme/size for Wayland (matches the old GTK/Xresources value).
      home.pointerCursor = {
        enable = true;
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
        gtk.enable = true;
      };
    };
}
