{
  projectRootFile = "flake.nix";

  # nixfmt is the same derivation nil_ls delegates to in modules/neovim, so
  # `nix fmt` and <leader>f on a .nix buffer cannot disagree.
  programs.nixfmt.enable = true;
  programs.stylua.enable = true;
  programs.shfmt.enable = true;

  # A LuaSnip data table laid out by hand. stylua breaks every parse() carrying
  # a [[...]] string across four lines, which no setting suppresses.
  settings.formatter.stylua.excludes = [ "modules/neovim/snippets.lua" ];

  # Markdown stays hand-formatted: the documentation conventions in CLAUDE.md
  # are prose rules no formatter expresses, and prettier reflows against them.
  settings.global.excludes = [
    "*.md"
    "*.json"
    "flake.lock"
    ".gitignore"
  ];
}
