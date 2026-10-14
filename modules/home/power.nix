{
  config,
  lib,
  ...
}:
let
  pkgs = config.station.pkgs;
in
{
  config.station.home =
    { ... }:
    {
      # Idle / power management, all systemd - no shell scripts.
      #
      # swayidle runs as a systemd user service. home-manager binds it to
      # graphical-session.target, but on NixOS the Sway session activates
      # sway-session.target, and only after importing WAYLAND_DISPLAY into the
      # systemd user manager. Because swayidle's unit has
      # ConditionEnvironment=WAYLAND_DISPLAY, binding it to graphical-session.target
      # makes the condition evaluate too early and the unit is skipped. Re-bind it to
      # sway-session.target so it starts once the environment exists.
      #
      # Schedule: hibernate at 10 min (battery only, see
      # hibernate-on-battery.service). The lock/panel-off timeouts are longer and
      # are reached only if hibernation is skipped (i.e. on AC).
      services.swayidle = {
        enable = true;
        timeouts = [
          {
            timeout = 900;
            command = "${pkgs.swaylock}/bin/swaylock -f";
          }
          {
            timeout = 930;
            command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
            resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
          }
          {
            timeout = 600;
            command = "${pkgs.systemd}/bin/systemctl --user start hibernate-on-battery.service";
          }
        ];
        events.before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
      };

      systemd.user.services.swayidle = {
        Unit = {
          PartOf = lib.mkForce [ "sway-session.target" ];
          After = lib.mkForce [ "sway-session.target" ];
        };
        Install.WantedBy = lib.mkForce [ "sway-session.target" ];
      };

      # Battery-only hibernate. ConditionACPower is evaluated natively by systemd:
      # on AC the unit is skipped, so the session only locks and blanks.
      systemd.user.services.hibernate-on-battery = {
        Unit = {
          Description = "Hibernate after idle when running on battery";
          ConditionACPower = false;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl hibernate";
        };
      };
    };
}
