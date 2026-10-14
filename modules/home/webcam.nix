{
  config,
  ...
}:
let
  pkgs = config.station.pkgs;
in
{
  config.station.home =
    { config, ... }:
    let
      device = "/dev/video0";
      resetScript = "${config.home.homeDirectory}/.local/bin/webcam-wb.sh";
    in
    {
      # The USB webcam sometimes comes up with a warm/yellow auto white balance.
      # This oneshot runs at login and toggles auto white balance to force a fresh
      # calibration. See files/local-bin/webcam-wb.sh.
      systemd.user.services.webcam-white-balance = {
        Unit.Description = "Reset the USB webcam auto white balance";
        Service = {
          Type = "oneshot";
          ExecStart = resetScript;
          Environment = [
            "WEBCAM_DEVICE=${device}"
            "PATH=${pkgs.v4l-utils}/bin:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
