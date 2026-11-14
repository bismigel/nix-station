# NixOS system configurations, built from the same inputs as the standalone
# home-manager hosts. The home-manager config is the merged `station.home`
# module (modules/home/*.nix), reused here via `home-manager.users.<name>`.
{ config, inputs, ... }:
{
  flake.nixosConfigurations.labanos = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
      ../nixos/labanos.nix
      {
        # One nixpkgs instance for everything: the system, the embedded Home
        # Manager (useGlobalPkgs) and every `config.station.pkgs` reference in
        # modules/home/*. Without this, NixOS configures an instance of its own
        # while home modules use a second one, and nixpkgs-level settings
        # (allowUnfree, overlays, problems.handlers) disagree between them.
        nixpkgs.pkgs = config.station.pkgs;
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
