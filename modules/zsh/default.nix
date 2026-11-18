{
  config,
  lib,
  forAllUsers,
  ...
}:

with lib;

let
  cfg = config.my.zsh;

in
{
  options.my.zsh.enable = mkEnableOption "zsh shell";

  config = mkIf cfg.enable {
    environment.pathsToLink = [ "/share/zsh" ];

    programs.zsh.enable = true;

    home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
  };
}
