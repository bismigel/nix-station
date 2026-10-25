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
    { config, ... }:
    let
      # Absolute path to the idle guard installed by modules/home/scripts.nix.
      # Must not be written as $HOME/... : systemd treats $VAR in an Exec line as
      # environment-variable syntax, splitting it on whitespace.
      idleGuard = "${config.xdg.configHome}/scripts/idle-power-guard.sh";
    in
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
      # Schedule: hibernate at 10 min on battery (see hibernate-on-battery.service).
      #
      # swayidle timeouts are static, but the wanted schedule depends on the power
      # source, and running two swayidle instances would double-fire. So every
      # branch is registered unconditionally and idle-power-guard.sh decides at
      # fire time whether it applies right now:
      #
      #   AC      : lock at 2 hours, blank 30 s later. before-sleep still locks
      #             on lid/suspend.
      #   battery : hibernate at 10 min; lock at 15 min and blank at 15.5 min as a
      #             fallback if hibernation was skipped or failed.
      services.swayidle = {
        enable = true;
        timeouts = [
          # Battery-only hibernate; ConditionACPower makes it a no-op on AC.
          {
            timeout = 600;
            command = "${pkgs.systemd}/bin/systemctl --user start hibernate-on-battery.service";
          }
          # Battery: lock, then blank, if the session is still awake.
          {
            timeout = 900;
            command = "${idleGuard} on-battery lock";
          }
          {
            timeout = 930;
            command = "${idleGuard} on-battery dpms-off";
            resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
          }
          # AC: two hours.
          {
            timeout = 7200;
            command = "${idleGuard} on-ac lock";
          }
          {
            timeout = 7230;
            command = "${idleGuard} on-ac dpms-off";
            resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
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

      # Audio-driven idle inhibitor: holds an idle inhibitor while anything is
      # playing, so a call or a video does not count as "idle" and get locked
      # mid-sentence.
      #
      # This used to be an `exec` in the sway config that waited for the pulse
      # socket first. sway does not restart a failed `exec`, and the wait loop
      # could still lose the race, which left no inhibitor running at all - so
      # calls locked the session. A unit with Restart=always cannot end up in
      # that state.
      systemd.user.services.sway-audio-idle-inhibit = {
        Unit = {
          Description = "Inhibit idle while audio is playing";
          PartOf = [ "sway-session.target" ];
          After = [ "sway-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
          Restart = "always";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
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
