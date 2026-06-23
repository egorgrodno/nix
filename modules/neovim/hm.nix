{ pkgs, keyboardLayout, ... }:

{
  home.packages = with pkgs; [
    # Runtime tools the editor shells out to.
    ripgrep   # telescope live_grep / grep_string
    fd        # telescope find_files (falls back to `find` if absent)
    nodejs    # runtime for the node-based language servers below

    # Language servers.
    bash-language-server
    typescript-language-server
    vscode-langservers-extracted
    nil
    rust-analyzer
    cargo
    rustc
    haskell.compiler.ghc96
    haskellPackages.haskell-language-server
    arduino-language-server
  ];

  xdg.configFile."nvim/snippets/all.lua".source = ./snippets.lua;

  xdg.configFile."nvim/lua/config.lua".text = import ./lua-config.nix {
    config = { base.keyboard.layout = keyboardLayout; };
  };

  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
    plugins = [
      {
        plugin = pkgs.vimPlugins.packer-nvim;
        type = "viml";
        config = ''
          packadd! packer.nvim
          lua require('config')
        '';
      }
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: with p; [
        c cpp css dockerfile go haskell html javascript json lua nix rust scss tsx typescript vim yaml
      ]))
    ];
  };
}
