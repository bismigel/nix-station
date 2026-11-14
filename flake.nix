{
  description = "Personal Sway/Wayland desktops - declarative Home Manager setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning (LUKS + btrfs for the NixOS hosts).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dendritic pattern tooling: flake-parts is the top-level module system,
    # import-tree recursively imports every module under ./modules so files
    # never have to be listed by hand.
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";

    # The native RuneScape 3 client still links OpenSSL 1.1, which was removed
    # from nixpkgs as end-of-life. Pin an older nixpkgs just to source it.
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-23.11";

    # Brave was dropped from nixos-unstable (#582838, no maintainer) and re-added
    # on master (#584534) a few days later. Pinned to that master commit just to
    # source `brave` until nixos-unstable catches up; then drop this input.
    nixpkgs-brave.url = "github:NixOS/nixpkgs/b754bb1b83ee7189bf7372279e9a5e25d2e35f0f";

    # Literate (Org) Emacs configuration. Tangled into ~/.emacs.d at build time
    # by modules/home/emacs.nix.
    #
    # Builds from the pushed repository, so the flake evaluates anywhere. Push
    # the rewrite before switching, or the build uses the older published tree.
    emacsorg = {
      url = "github:prawnfarmerdev/emacsorg";
      flake = false;
    };
  };

  # Dendritic entry point: the whole ./modules tree is the top-level
  # configuration. No module has to be imported or listed by hand.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
