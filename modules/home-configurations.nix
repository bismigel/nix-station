{
  config,
  inputs,
  ...
}:
{
  # The merged home-manager module, published for reuse (e.g. from a NixOS
  # host via `inputs.nix-station.homeModules.default`).
  flake.homeModules.default = config.station.home;

  flake.homeConfigurations."${config.station.identity.username}" =
    inputs.home-manager.lib.homeManagerConfiguration
      {
        pkgs = config.station.pkgs;
        modules = [ config.station.home ];
      };
}
