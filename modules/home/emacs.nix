{
  config,
  inputs,
  ...
}:
let
  pkgs = config.station.pkgs;

  # prawnfarmerdev/emacsorg is a literate config: readme.org is the source of
  # truth and tangles to ~/.emacs.d/{init.el,early-init.el} plus a theme at
  # ~/.emacs.d/config/theme.el.
  #
  # Writes to $HOME are not allowed in the Nix sandbox, so rewrite the tangle
  # targets to the build directory, let Emacs emit the files there, and then
  # symlink the result into place with home.file below. This keeps the upstream
  # Org file authoritative - bump inputs.emacsorg to update the config.
  emacsConfig =
    pkgs.runCommand "emacsorg-config"
      {
        nativeBuildInputs = [ pkgs.emacs ];
      }
      ''
        mkdir -p work $out

        # Rewrite the tangle targets to the build directory (writes to $HOME are
        # not allowed in the Nix sandbox); the font is set upstream in readme.org.
        cp ${inputs.emacsorg}/readme.org work/readme.org
        sed -i "s|~/.emacs.d/|$out/|g" work/readme.org

        emacs -Q --batch \
          --eval '(progn (require (quote org)) (find-file "work/readme.org") (org-babel-tangle))'

        mkdir -p $out/config
        cp ${inputs.emacsorg}/config/theme.el $out/config/theme.el
      '';

  # Tree-sitter grammars built by nixpkgs (lib/libtree-sitter-*.so). They are
  # exposed both via EMACS_TREESIT_GRAMMARS and at Emacs's default
  # ~/.emacs.d/tree-sitter search path, so no grammar is ever compiled at
  # runtime (there is no C compiler on PATH).
  treesitGrammars = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).treesit-grammars.with-all-grammars;
in
{
  config.station.home =
    { ... }:
    {
      home.file.".emacs.d/early-init.el".source = "${emacsConfig}/early-init.el";
      home.file.".emacs.d/init.el".source = "${emacsConfig}/init.el";
      home.file.".emacs.d/config/theme.el".source = "${emacsConfig}/config/theme.el";

      # Emacs searches ~/.emacs.d/tree-sitter by default, so put the
      # Nix-built grammars there too. This makes tree-sitter work even when the
      # EMACS_TREESIT_GRAMMARS env var / treesit-extra-load-path setup hasn't
      # run yet, and stops treesit-auto from trying to compile with `cc`.
        home.file.".emacs.d/tree-sitter".source = "${treesitGrammars}/lib";
        home.file.".emacs.d/herdr".source = "${inputs.herdr-el}";

      home.packages = [ treesitGrammars ];
      home.sessionVariables.EMACS_TREESIT_GRAMMARS = "${treesitGrammars}/lib";
    };
}
