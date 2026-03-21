{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gpclient
    slack
  ];
}
