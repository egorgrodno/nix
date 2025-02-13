{ pkgs, config, username, ... }:

{
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      bash-language-server
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted
      nil
      rust-analyzer
      cargo
      rustc
      haskell.compiler.ghc96
      haskellPackages.haskell-language-server
    ];

    xdg.configFile."nvim/snippets/all.lua".source = ./snippets.lua;

    xdg.configFile."nvim/lua/config.lua".text = import ./lua-config.nix { inherit config; };

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      defaultEditor = true;
      plugins = [{
        plugin = pkgs.vimPlugins.packer-nvim;
        config = ''
          packadd! packer.nvim
          lua require('config')
        '';
      }];
    };
  };
}
