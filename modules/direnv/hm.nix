{ ... }:

{
  # nix-direnv caches `use flake` and `use nix` and pins a GC root, so a dev shell
  # survives `nix-collect-garbage`. home-manager hooks only a shell whose rc file
  # it owns: zsh on the hosts, none in the standalone `neovim-*` profiles, which
  # the README tells to add the hook by hand.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
