{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.neovim ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    configure = {
      packages.myPlugins = with pkgs.vimPlugins;
        { start =
            [
              auto-pairs
              coc-nvim
              # extensions: coc-angular coc-eslint coc-git coc-prettier
              #             coc-smartf coc-tslint-plugin coc-tsserver
              ctrlp
              indentLine
              lightline-bufferline
              lightline-vim
              nerdtree
              nord-vim
              vim-commentary
              vim-nix
              vim-surround
              yats-vim
            ];
          opt =
            [
              goyo-vim
              haskell-vim
              vim-pug
            ];
        };
      customRC = builtins.readFile ./init.vim;
    };
  };
}
