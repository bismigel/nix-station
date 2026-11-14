{
  config,
  ...
}:
{
  config.station.home =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Installed by modules/home/scripts.nix. Absolute path, not $HOME/... -
      # systemd treats $VAR in an Exec line as environment-variable syntax.
      audioFollow = "${config.xdg.configHome}/scripts/audio-follow-output.sh";
    in
    {
      # Keep the default microphone on the same hardware as the current output.
      #
      # The noise-cancelling mic belongs to the headset, so playing to the
      # headset while recording from the internal mic silently loses it.
      # PipeWire/WirePlumber do not link the two, so this watches for output
      # changes and repoints the default source at the input of the same
      # device.id.
      #
      # A unit rather than a sway `exec`: sway does not restart a failed exec,
      # and this has to survive output hotplug for the whole session.
      systemd.user.services.audio-follow-output = {
        Unit = {
          Description = "Follow the default sink with the default source";
          PartOf = [ "sway-session.target" ];
          After = [ "sway-session.target" ];
        };
        Service = {
          ExecStart = audioFollow;
          Restart = "always";
          RestartSec = 3;
          # pactl/pw-dump/jq/awk are not on a user unit's PATH by default; the
          # script resolves them itself, but spell out a working PATH so it does
          # not have to.
          Environment = [
            "PATH=${
              lib.makeBinPath (
                with pkgs;
                [
                  bash
                  coreutils
                  jq
                  pulseaudio
                  pipewire
                ]
              )
            }:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin"
          ];
        };
        Install.WantedBy = [ "sway-session.target" ];
      };
    };
}
