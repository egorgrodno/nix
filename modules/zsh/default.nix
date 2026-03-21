{ config, lib, users, ... }:

with lib;

let
  cfg = config.zsh;

in {
  options.zsh.enable = mkEnableOption "zsh shell";

  config = mkIf cfg.enable {
    environment = {
      variables.KEYTIMEOUT = "1";
      pathsToLink = [ "/share/zsh" ];
    };

    programs.zsh.enable = true;
    programs.zsh.autosuggestions.enable = true;

    home-manager.users = builtins.listToAttrs (map (u: {
      name = u.name;
      value = { imports = [ ./hm.nix ]; };
    }) users);
  };
}
