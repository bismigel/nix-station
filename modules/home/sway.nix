{ ... }:
{
  config.station.home =
    { pkgs, ... }:
    {
      # ---- Sway window manager (Wayland) ----
      xdg.configFile."sway/config".source = ../../files/sway/config;

      # ---- Lock screen (solid black background) ----
      xdg.configFile."swaylock/config".source = ../../files/swaylock/config;

      # ---- Bar: waybar (replaces swaybar; see files/sway/config) ----
      xdg.configFile."waybar/config".source = ../../files/waybar/config;
      xdg.configFile."waybar/style.css".source = ../../files/waybar/style.css;

      # Used to be `exec waybar` in the sway config. sway does not restart a
      # failed `exec`, so when waybar's D-Bus thread aborted mid-session - a
      # `nixos-rebuild switch` reloading dbus-broker is enough, the tray module
      # dies on the dropped connection - the bar stayed gone until sway itself
      # was restarted. `swaymsg reload` does not re-run `exec` lines either.
      # A unit with Restart=always cannot end up in that state.
      systemd.user.services.waybar = {
        Unit = {
          Description = "Waybar status bar";
          PartOf = [ "sway-session.target" ];
          After = [ "sway-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          ExecStart = "${pkgs.waybar}/bin/waybar";
          Restart = "always";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

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
