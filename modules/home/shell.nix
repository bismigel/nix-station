{ ... }:
{
  config.station.home =
    { ... }:
    {
      programs.bash = {
        enable = true;
        enableCompletion = true;

        shellAliases = {
          ls = "ls --color=auto";
        };

        initExtra = ''
          # Prompt
          PS1='[\u@\h \W]\$ '
        '';
      };
    };
}
