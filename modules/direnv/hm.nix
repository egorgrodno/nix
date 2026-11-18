{ ... }:

{
  # nix-direnv caches `use flake` and `use nix` and pins a GC root, so a dev shell
  # survives `nix-collect-garbage`. home-manager hooks only a shell whose rc file
  # it owns, which is zsh; the README covers hooking another by hand.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
