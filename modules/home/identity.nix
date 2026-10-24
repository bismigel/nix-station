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
      };

      # Cursor theme/size for Wayland (matches the old GTK/Xresources value).
      home.pointerCursor = {
        enable = true;
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 32;
        gtk.enable = true;
      };
    };
}
