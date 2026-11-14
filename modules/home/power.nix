{
  config,
  lib,
  ...
}:
let
  pkgs = config.station.pkgs;
  # swayidle runs timeout commands through `sh -c` with whatever PATH
  # home-manager gives its unit - bash only, on purpose (see below). Every
  # binary invoked from a timeout is therefore an absolute path.
  startUnit = unit: "${pkgs.systemd}/bin/systemctl --user start ${unit}.service";
  dpmsOn = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
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
      # ConditionEnvironment=WAYLAND_DISPLAY, binding it to
      # graphical-session.target makes the condition evaluate too early and the
      # unit is skipped. Re-bind it to sway-session.target so it starts once the
      # environment exists.
      #
      # Schedule:
      #
      #   AC      : lock at 2 hours, blank 30 s later. before-sleep still locks
      #             on lid/suspend, and nothing hibernates on AC (see logind).
      #   battery : lock at 10 min, blank at 10.5 min, hibernate at 15 min.
      #             Lock first: if hibernation is refused or fails, the screen is
      #             already dark and locked instead of sitting open.
      #
      # swayidle's timeouts are static, but the wanted schedule depends on the
      # power source. Two swayidle instances would double-fire, and restarting
      # one to swap schedules would reset the idle clock, so every branch is
      # registered unconditionally and each timeout starts a *unit* carrying
      # ConditionACPower. systemd evaluates that condition at start time - the
      # same mechanism hibernate-on-battery uses - so deciding "is this the AC
      # schedule or the battery one" needs no script, and starting the unit for
      # the other power source is a no-op.
      services.swayidle = {
        enable = true;
        timeouts = [
          # Battery: lock, blank, then hibernate on the same idle run.
          {
            timeout = 600;
            command = startUnit "swayidle-lock-on-battery";
          }
          {
            timeout = 630;
            command = startUnit "swayidle-dpms-off-on-battery";
            resumeCommand = dpmsOn;
          }
          {
            timeout = 900;
            command = startUnit "hibernate-on-battery";
          }
          # AC: two hours.
          {
            timeout = 7200;
            command = startUnit "swayidle-lock-on-ac";
          }
          {
            timeout = 7230;
            command = startUnit "swayidle-dpms-off-on-ac";
            resumeCommand = dpmsOn;
          }
        ];
        events.before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
      };

      systemd.user.services = {
        # Unit definition is home-manager's (it wraps the timeout commands in
        # `sh -c`, hence the bash-only PATH); only the target it hangs off
        # changes.
        swayidle = {
          Unit = {
            PartOf = lib.mkForce [ "sway-session.target" ];
            After = lib.mkForce [ "sway-session.target" ];
          };
          Install.WantedBy = lib.mkForce [ "sway-session.target" ];
        };

        # One unit per idle action per power source. ConditionACPower lets
        # systemd make the AC/battery decision; the mismatch case is skipped
        # rather than guarded in shell.
        swayidle-lock-on-ac = {
          Unit = {
            Description = "Lock the session after idle on AC";
            ConditionACPower = true;
          };
          Service = {
            # Not oneshot: swaylock stays in the foreground for as long as the
            # screen is locked, and `systemctl start` has to return immediately
            # so swayidle is not blocked.
            ExecStart = "${pkgs.swaylock}/bin/swaylock -f";
          };
        };
        swayidle-lock-on-battery = {
          Unit = {
            Description = "Lock the session after idle on battery";
            ConditionACPower = false;
          };
          Service.ExecStart = "${pkgs.swaylock}/bin/swaylock -f";
        };
        swayidle-dpms-off-on-ac = {
          Unit = {
            Description = "Blank the outputs after idle on AC";
            ConditionACPower = true;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
          };
        };
        swayidle-dpms-off-on-battery = {
          Unit = {
            Description = "Blank the outputs after idle on battery";
            ConditionACPower = false;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
          };
        };

        # Battery-only hibernate. ConditionACPower is evaluated natively by
        # systemd: on AC the unit is skipped, so the session only locks and
        # blanks.
        hibernate-on-battery = {
          Unit = {
            Description = "Hibernate after idle when running on battery";
            ConditionACPower = false;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl hibernate";
          };
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
        sway-audio-idle-inhibit = {
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
      };
    };
}
