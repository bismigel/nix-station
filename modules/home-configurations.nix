{
  config,
  inputs,
  lib,
  ...
}:
{
  # The merged home-manager module, published for reuse (e.g. from a NixOS
  # host via `inputs.nix-station.homeModules.default`).
  flake.homeModules.default = config.station.home;

  # One home configuration per host in `station.hosts`. Every host gets the
  # same merged module; only the username and home directory differ.
  flake.homeConfigurations = lib.mapAttrs'
    (host: cfg:
      lib.nameValuePair host (
        inputs.home-manager.lib.homeManagerConfiguration
          {
            pkgs = config.station.pkgs;
            modules = [
              config.station.home
              ({ ... }: {
                home.username = cfg.username;
                home.homeDirectory = "/home/${cfg.username}";
              })
            ];
          }
      ))
    config.station.hosts;
}
