{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../home.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  powerManagement.cpuFreqGovernor = "ondemand";

  networking.hostName = "thinkpad";
  networking.interfaces.enp4s0.useDHCP = true;
  networking.interfaces.wlp5s0.useDHCP = true;

  system.stateVersion = "21.11";
}
