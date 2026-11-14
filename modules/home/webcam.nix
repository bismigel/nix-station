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
    {
      # The internal camera sometimes comes up with a warm/yellow auto white
      # balance. This oneshot runs at login and toggles auto white balance off
      # and back on to force a fresh calibration.
      #
      # files/local-bin/webcam-wb.sh finds the camera by name ("Laptop Camera")
      # rather than assuming /dev/video0: the UVC device owns video0, video1 and
      # media0, and the numbering is not stable across suspend/resume. Set
      # WEBCAM_DEVICE to pin an explicit node.
      systemd.user.services.webcam-white-balance = {
        Unit = {
          Description = "Reset the USB webcam auto white balance";
          # A login without a camera attached has nothing to calibrate.
          ConditionPathExistsGlob = "/dev/video*";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${config.home.homeDirectory}/.local/bin/webcam-wb.sh";
          Environment = [
            "PATH=${pkgs.v4l-utils}/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/bin:/bin"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
