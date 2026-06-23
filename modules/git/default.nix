{ config, pkgs, forAllUsers, ... }:

{
  environment.systemPackages =
    if config.base.isNixosSystem
      then with pkgs; [ git gh glab ]
      else [];

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
