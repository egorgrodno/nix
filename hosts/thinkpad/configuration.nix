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
      device = "nodev";
      useOSProber = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  powerManagement.cpuFreqGovernor = "ondemand";

  networking.hostName = "thinkpad";
  networking.interfaces.enp4s0.useDHCP = true;
  networking.interfaces.wlp5s0.useDHCP = true;

  system.stateVersion = "21.11";
}
