{ config, ... }:
{
  config.station.home =
    { pkgs, ... }:
    {
      # herdr theme / onboarding state (read from ~/.config/herdr/config.toml).
      xdg.configFile."herdr/config.toml".source = ../../files/herdr/config.toml;

      systemd.user.services.herdr = {
        Unit = {
          Description = "herdr headless server";
          After = [ "default.target" ];
        };
        Service = {
          ExecStart = "${pkgs.herdr}/bin/herdr server";
          ExecStop = "${pkgs.herdr}/bin/herdr server stop";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
