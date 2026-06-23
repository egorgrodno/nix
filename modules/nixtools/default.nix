{ pkgs, forAllUsers, ... }:

{
  environment.systemPackages = [ pkgs.pciutils ];

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
