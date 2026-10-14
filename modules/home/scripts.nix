{ ... }:
{
  config.station.home =
    { ... }:
    {
      # Custom helper scripts, kept at the same paths the i3 config expects.
      xdg.configFile."scripts" = {
        source = ../../files/scripts;
        recursive = true;
      };

      home.file.".local/bin" = {
        source = ../../files/local-bin;
        recursive = true;
      };
    };
}
