{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
    ../../roles/role-laptop.nix
    # ../../roles/role-nextcloud-client.nix
    # ../../roles/role-vm-host.nix
  ];

  base.keyboard = {
    layout = "qwerty";
    swapCapsEscape = true;
  };

  my.desktop.primaryScreen = "eDP-1";

  # Wifi and Bluetooth firmware, and the AMD microcode the hardware file wires up.
  hardware.enableRedistributableFirmware = true;

  boot.loader = {
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      device = "nodev";
      useOSProber = false;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    # Keyboard-interactive goes through PAM, which prompts for the same password.
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
