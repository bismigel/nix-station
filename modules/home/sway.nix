{ ... }:
let
  # Every session daemon in this repo used to be a bare `exec` line in
  # files/sway/config. That is wrong here for a documented reason: sway does not
  # restart a failed `exec`, and `swaymsg reload` never re-runs one, so a crashed
  # bar/applet/notification daemon stays gone for the whole session. A user unit
  # with a restart policy cannot end up in that state.
  #
  # ConditionEnvironment is what keeps these from starting outside a Wayland
  # session: home-manager binds units to graphical-session.target, but on NixOS
  # the Sway session activates sway-session.target, so these are bound to that
  # instead (see modules/home/power.nix for the full explanation).
  #
  # `Restart = "on-failure"` on purpose: dunst, nm-applet, blueman-applet, the
  # polkit agent and power-manager.sh all exit 0 when another instance (or the
  # same instance after an initial start) already holds their bus name. A
  # `Restart = "always"` would spin on that. Daemons that must run - waybar,
  # audio-follow-output, sway-audio-idle-inhibit - keep `always`.
  sessionUnit =
    {
      description,
      execStart,
      path,
      restart ? "on-failure",
    }:
    {
      Unit = {
        Description = description;
        PartOf = [ "sway-session.target" ];
        After = [ "sway-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = execStart;
        Restart = restart;
        RestartSec = 3;
        # User units do not inherit the session PATH reliably (the user manager
        # captures it at login, and home-manager's own units get a deliberately
        # minimal one), so every unit that runs a script spells it out.
        Environment = [ "PATH=${path}" ];
      };
      Install.WantedBy = [ "sway-session.target" ];
    };
in
{
  config.station.home =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sessionPath = "${
        lib.makeBinPath (
          with pkgs;
          [
            bash
            coreutils
            util-linux
            systemd
            sway
            jq
            libnotify
          ]
        )
      }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
    in
    {
      # ---- Sway window manager (Wayland) ----
      xdg.configFile."sway/config".source = ../../files/sway/config;

      # ---- Lock screen (solid black background) ----
      xdg.configFile."swaylock/config".source = ../../files/swaylock/config;

      # ---- Bar: waybar (replaces swaybar + i3status) ----
      # waybar, not swaybar: swaybar's tray only forwards StatusNotifierItem
      # method calls and never renders a menu (no dbusmenu implementation), so
      # the tray right-click menus of blueman/nm-applet/Proton VPN could not work.
      xdg.configFile."waybar/config".source = ../../files/waybar/config;
      xdg.configFile."waybar/style.css".source = ../../files/waybar/style.css;

      systemd.user.services = {
        waybar = sessionUnit {
          description = "Waybar status bar";
          execStart = "${pkgs.waybar}/bin/waybar";
          path = sessionPath;
          restart = "always";
        };

        # Polkit authentication agent. `polkit_gnome` is only a package, and its
        # etc/xdg/autostart entry is inert because sway does not implement the
        # XDG autostart spec - so without this unit every GUI privilege prompt
        # (udisks2 mounts, fwupd, pkexec tools) fails with no dialog.
        polkit-gnome-authentication-agent-1 = sessionUnit {
          description = "Polkit authentication agent (GNOME)";
          execStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          path = sessionPath;
        };

        # Notification daemon (dunstrc in modules/home/desktop.nix).
        dunst = sessionUnit {
          description = "Dunst notification daemon";
          execStart = "${pkgs.dunst}/bin/dunst";
          path = sessionPath;
        };

        # Tray applets. blueman-manager is bound to $mod+Shift+b in the config.
        nm-applet = sessionUnit {
          description = "NetworkManager tray applet";
          execStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
          path = sessionPath;
        };
        blueman-applet = sessionUnit {
          description = "Bluetooth tray applet";
          execStart = "${pkgs.blueman}/bin/blueman-applet";
          path = sessionPath;
        };

        # Panel refresh rate on AC/battery (reads sway output modes itself).
        power-manager = sessionUnit {
          description = "Panel refresh-rate manager (AC/battery)";
          execStart = "${config.xdg.configHome}/scripts/power-manager.sh";
          path = sessionPath;
        };

        # Feeds /tmp/weather.txt for waybar's custom/weather module.
        weather-daemon = sessionUnit {
          description = "Weather poller for waybar";
          execStart = "${config.xdg.configHome}/scripts/weather_daemon.sh";
          path = sessionPath;
        };
      };
    };
}
