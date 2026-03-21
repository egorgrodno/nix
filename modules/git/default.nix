{ config, pkgs, users, ... }:

{
  environment.systemPackages =
    if config.base.isNixosSystem
      then with pkgs; [ git gh glab ]
      else [];

  home-manager.users = builtins.listToAttrs (map (u: {
    name = u.name;
    value = { imports = [ ./hm.nix ]; };
  }) users);
}
