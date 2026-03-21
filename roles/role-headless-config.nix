{ pkgs, ... }:

{
  imports = [
    ./role-base-config.nix
  ];

  base.isHeadless = true;
  base.keyboard.layout = "qwerty";

  environment.systemPackages = [ pkgs.kitty.terminfo ];
}
