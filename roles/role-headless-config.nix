{ ... }:

{
  imports = [
    ./role-base-config.nix
  ];

  base.isHeadless = true;
  base.keyboard.layout = "qwerty";
}
