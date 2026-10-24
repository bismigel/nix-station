# NixOS system configurations, built from the same inputs as the standalone
# home-manager hosts. The home-manager config is the merged `station.home`
# module (modules/home/*.nix), reused here via `home-manager.users.<name>`.
{ config, inputs, ... }:
{
  flake.nixosConfigurations.labanos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
      ../nixos/labanos.nix
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.labanos = {
            imports = [ config.station.home ];
            home.username = "labanos";
            home.homeDirectory = "/home/labanos";
            targets.genericLinux.enable = false;
          };
        };
      }
    ];
  };
}
