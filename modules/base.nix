{
  config,
  inputs,
  lib,
  ...
}:
let
  system = "x86_64-linux";
in
{
  # The top-level configuration owns the values that lower-level (home-manager)
  # modules need. Feature modules read these from the top-level `config` and
  # close over them, so nothing has to be threaded through `extraSpecialArgs`.
  options.station = {
    # One nixpkgs instance, shared by the flake and by the home configuration.
    pkgs = lib.mkOption {
      type = lib.types.pkgs;
    };

    # The home-manager configuration, assembled by merging the assignments in
    # every modules/home/*.nix file.
    home = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
    };

    # Per-host home configurations: hostname -> { username }. Every host gets
    # the same merged home module; only the username/home directory differ.
    hosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.username = lib.mkOption {
            type = lib.types.str;
          };
        }
      );
      default = { };
    };
  };

  config.systems = [ system ];

  # One nixpkgs instance, shared by the flake and by the home configuration.
  # Also published as `flake.station.pkgs` so a NixOS host (this repo's or an
  # external one) can point `nixpkgs.pkgs` at the same instance the home module
  # closes over, instead of configuring a second one.
  config.flake.station.pkgs = config.station.pkgs;

  config.station.hosts = {
    nixos.username = "okra";
    labanos.username = "labanos";
  };

  config.station.pkgs = import inputs.nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      # bolt-launcher marks itself broken with enableRS3 because RS3 needs
      # OpenSSL 1.1; we supply it ourselves, so ignore the warning.
      problems.handlers.bolt-launcher.broken = "ignore";
      # The RS3 client is GTK2-only and gtk2 is now flagged broken pending
      # removal in NixOS 27.05 (#410814). Nothing else here pulls it in; keep
      # the old client running rather than dropping gaming on this host.
      problems.handlers."gtk+".broken = "ignore";
    };
  };
}
