{
  config,
  ...
}:
let
  pkgs = config.station.pkgs;
in
{
  config.station.home =
    { ... }:
    {
      # ---- Notification daemon ----
      xdg.configFile."dunst/dunstrc".source = ../../files/dunst/dunstrc;

      # ---- Application launcher ----
      xdg.configFile."rofi/config.rasi".source = ../../files/rofi/config.rasi;
      # Dark theme referenced by config.rasi (kept next to it, relative import).
      xdg.configFile."rofi/Arc-Dark.rasi".source = "${pkgs.rofi}/share/rofi/themes/Arc-Dark.rasi";

      # ---- Terminals ----
      xdg.configFile."kitty/kitty.conf".source = ../../files/kitty/kitty.conf;
      xdg.configFile."wezterm/wezterm.lua".source = ../../files/wezterm/wezterm.lua;

      # ---- System monitor ----
      xdg.configFile."btop/btop.conf".source = ../../files/btop/btop.conf;

      # ---- GTK (font + cursor sizing) ----
      home.file.".gtkrc-2.0".source = ../../files/gtkrc-2.0;
      xdg.configFile."gtk-3.0/settings.ini".source = ../../files/gtk-3.0/settings.ini;
      xdg.configFile."gtk-4.0/settings.ini".source = ../../files/gtk-4.0/settings.ini;
    };
}
