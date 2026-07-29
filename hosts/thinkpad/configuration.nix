{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
    # ../../roles/role-nextcloud-client.nix
    # ../../roles/role-vm-host.nix
  ];

  my.desktop.primaryScreen = "eDP-1";

  # Intel integrated graphics; no discrete GPU on this machine.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # Wifi and Bluetooth firmware, and the Intel microcode the hardware file wires up.
  hardware.enableRedistributableFirmware = true;

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

  # Laptop power handling. TLP owns the CPU frequency governor, so this host must
  # not set `powerManagement.cpuFreqGovernor` — the two fight over the same knob.
  services.tlp.enable = true;
  services.thermald.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
  };

  networking.hostName = "thinkpad";
  networking.useDHCP = lib.mkDefault true;

  system.stateVersion = "21.11";
}
