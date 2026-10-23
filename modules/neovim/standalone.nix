# The editor without home-manager or packer, as `nvim-<layout>`, for the rescue
# stick. Of the language servers only nil comes along, as the stick edits Nix.
{
  lib,
  vimPlugins,
  neovim-unwrapped,
  wrapNeovimUnstable,
  writeShellScriptBin,
  fd,
  nil,
  nixfmt,
  ripgrep,
  layout,
}:

let
  nvim = wrapNeovimUnstable neovim-unwrapped {
    # packer's list in lua-config.nix. packer itself only has to answer the
    # startup call.
    plugins = with vimPlugins; [
      packer-nvim
      luasnip
      cmp-buffer
      cmp-cmdline
      cmp-nvim-lsp
      cmp-path
      nvim-cmp
      auto-pairs
      goyo-vim
      nvim-tree-lua
      indent-blankline-nvim
      nvim-lspconfig
      comment-nvim
      plenary-nvim
      lualine-nvim
      telescope-nvim
      onenord-nvim
      cmp_luasnip
      vim-eunuch
      vim-surround
      gitsigns-nvim
      neogit
      telescope-fzf-native-nvim
      telescope-ui-select-nvim
      actions-preview-nvim
      hop-nvim
      (import ./treesitter.nix vimPlugins)
    ];
    luaRcContent = import ./lua-config.nix {
      config.base.keyboard.layout = layout;
    };
    wrapperArgs = [
      "--suffix"
      "PATH"
      ":"
      (lib.makeBinPath [
        fd
        nil
        nixfmt
        ripgrep
      ])
    ];
  };
in
writeShellScriptBin "nvim-${layout}" ''exec ${nvim}/bin/nvim "$@"''
