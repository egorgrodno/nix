{ ... }:

{
  # nix-direnv supplies the cached `use flake` and pins a GC root, so a project's
  # dev shell survives `nix-collect-garbage`. Zsh integration is injected
  # automatically because programs.zsh.enable is set for every user.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
