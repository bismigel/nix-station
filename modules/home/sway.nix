{ ... }:
{
  config.station.home =
    { ... }:
    {
      # ---- Sway window manager (Wayland) ----
      xdg.configFile."sway/config".source = ../../files/sway/config;

      # ---- Lock screen (solid black background) ----
      xdg.configFile."swaylock/config".source = ../../files/swaylock/config;

      # ---- i3status (rendered by swaybar as the bottom bar) ----
      xdg.configFile."i3status/config".source = ../../files/i3status/config;
      xdg.configFile."i3status/scripts" = {
        source = ../../files/i3status/scripts;
        recursive = true;
      };
    };
}
