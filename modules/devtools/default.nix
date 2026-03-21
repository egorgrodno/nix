{ config, pkgs, users, ... }:

with pkgs;

let
  systemPackages = [
    wget
    htop
    zip
    unzip
    file
  ];
in {
  environment.systemPackages = if config.base.isNixosSystem
    then systemPackages
    else [];

  home-manager.users = builtins.listToAttrs (map (u: {
    name = u.name;
    value = { imports = [ ./hm.nix ]; };
  }) users);
}
