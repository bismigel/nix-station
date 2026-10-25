{ ... }:
{
  config.station.home =
    { ... }:
    {
      # ---- Sway window manager (Wayland) ----
      xdg.configFile."sway/config".source = ../../files/sway/config;

      # ---- Lock screen (solid black background) ----
      xdg.configFile."swaylock/config".source = ../../files/swaylock/config;

      # ---- Bar: waybar (replaces swaybar; see files/sway/config) ----
      xdg.configFile."waybar/config".source = ../../files/waybar/config;
      xdg.configFile."waybar/style.css".source = ../../files/waybar/style.css;

      # ---- i3status ----
      # No longer rendered: waybar owns the bar now. The daemons under
      # i3status/scripts are still used, because they populate /tmp/*.txt for
      # waybar's custom/mic and custom/weather modules.
      xdg.configFile."i3status/config".source = ../../files/i3status/config;
      xdg.configFile."i3status/scripts" = {
        source = ../../files/i3status/scripts;
        recursive = true;
      };
    };
}
