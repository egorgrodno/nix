{ pkgs, lib, ... }:

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

  environment.systemPackages = [ pkgs.postgresql ];
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    dataDir = "/data/postgresql";
  };

  powerManagement.cpuFreqGovernor = "ondemand";

  networking.hostName = "thinkpad";
  networking.useDHCP = lib.mkDefault true;

  system.stateVersion = "21.11";
}
