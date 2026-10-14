{
  description = "ASUS ROG / Sway workstation - declarative Home Manager setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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

    # Literate (Org) Emacs configuration. Tangled into ~/.emacs.d at build time
    # by modules/home/emacs.nix.
    #
    # Currently pinned to the local working copy while the no-Evil/ghostel
    # rewrite is in progress. Switch back to the GitHub URL once it is pushed:
    #   url = "github:prawnfarmerdev/emacsorg";
    emacsorg = {
      url = "path:/home/okra/projects/emacsorg";
      flake = false;
    };
  };

  # Dendritic entry point: the whole ./modules tree is the top-level
  # configuration. No module has to be imported or listed by hand.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
