{
  config,
  pkgs,
  forAllUsers,
  ...
}:

with pkgs;

let
  systemPackages = [
    wget
    htop
    zip
    unzip
    file
    config.boot.kernelPackages.perf
  ];
in
{
  environment.systemPackages = if config.base.isNixosSystem then systemPackages else [ ];

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
