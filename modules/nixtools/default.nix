{ pkgs, forAllUsers, ... }:

{
  environment.systemPackages = [
    pkgs.gum
    pkgs.pciutils
  ];

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
