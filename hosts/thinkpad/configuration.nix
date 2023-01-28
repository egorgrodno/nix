{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../home.nix
  ];

  boot.loader = {
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };

  powerManagement.cpuFreqGovernor = "ondemand";

  networking.hostName = "thinkpad";
  networking.interfaces.enp4s0.useDHCP = true;
  networking.interfaces.wlp5s0.useDHCP = true;

  system.stateVersion = "21.11";
}
