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
    let
      # One gdk-pixbuf loader cache covering every loader module in the closure:
      # gdk-pixbuf's own (tiff/gif/webp/jxl/...) plus librsvg's SVG loader.
      #
      # Pointing GDK_PIXBUF_MODULE_FILE at librsvg's cache (what this used to do)
      # only worked by accident: gdk-pixbuf compiles png and jpeg into the
      # library, and librsvg's cache happens to list those builtins, so PNG
      # icons decoded - but webp/jxl modules from other packages were invisible.
      # Generating the cache here means a loader added anywhere in the closure is
      # picked up instead of silently missing.
      gdkPixbufLoaders =
        pkgs.runCommand "gdk-pixbuf-loaders.cache"
          {
            nativeBuildInputs = [ pkgs.gdk-pixbuf.dev ];
          }
          ''
            cache=$(mktemp)
            for dir in \
              ${lib.getLib pkgs.gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders \
              ${lib.getLib pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders
            do
              [ -d "$dir" ] || continue
              gdk-pixbuf-query-loaders "$dir"/*.so >> "$cache"
            done
            install -m644 "$cache" $out
          '';
    in
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
        MESA_SHADER_CACHE_DIR = "${config.xdg.cacheHome}/mesa-shaders";

        # Run Wayland-native where possible.
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";

        # gdk-pixbuf needs a loader cache that includes SVG to decode themed
        # icons: blueman's StatusNotifierItem asks for IconName="blueman-active",
        # and its only icon is hicolor/scalable/status/blueman-active.svg - with
        # no SVG loader the tray shows `image-missing` (the red sad face).
        # nm-applet only appeared to work because its icon resolves to a PNG.
        # GTK apps started from a terminal inherit this from their wrapper, which
        # is why it looked set in an interactive shell but not in sway's own
        # environment. See gdkPixbufLoaders above.
        GDK_PIXBUF_MODULE_FILE = "${gdkPixbufLoaders}";
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
