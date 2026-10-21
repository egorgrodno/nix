{
  projectRootFile = "flake.nix";

  # nixfmt is the same derivation nil_ls delegates to in modules/neovim, so
  # `nix fmt` and <leader>f on a .nix buffer cannot disagree.
  programs.nixfmt.enable = true;
  # Unused bindings and arguments, removed in place, so the pre-commit hook and
  # checks.formatting catch dead code. nixfmt runs after it, to lay out what
  # its edits leave.
  programs.deadnix.enable = true;
  programs.nixfmt.priority = 1;
  programs.stylua.enable = true;
  programs.shfmt.enable = true;
  programs.gofmt.enable = true;

  # A LuaSnip data table laid out by hand. stylua breaks every parse() carrying
  # a [[...]] string across four lines, which no setting suppresses.
  settings.formatter.stylua.excludes = [ "modules/neovim/snippets.lua" ];

  # Markdown's mechanics only; the prose conventions in CLAUDE.md stay by hand.
  # prettier and deno fmt would pad every table into aligned columns.
  programs.rumdl-format.enable = true;

  settings.global.excludes = [
    "*.json"
    "flake.lock"
    ".gitignore"
  ];
}
