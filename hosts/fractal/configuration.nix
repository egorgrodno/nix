{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
  ];

  my.desktop = {
    primaryScreen = "HDMI-A-2";
    primaryMode = "2560x1440@120";
  };

  # NVIDIA on a hybrid AMD/NVIDIA board. PRIME runs in sync mode: the NVIDIA GPU
  # renders everything and the display is driven through it, so the bus IDs below
  # are this machine's and nothing else's.
  services.xserver.videoDrivers = [ "nvidia" ]; # still the driver knob under Wayland
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true; # Recommended for 40-series cards
    modesetting.enable = true;
    powerManagement.enable = true;
    prime = {
      sync.enable = true;
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:51:0:0";
      offload.enable = false;
      offload.enableOffloadCmd = false;
    };
  };
  boot.blacklistedKernelModules = [ "nouveau" ];
  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
  };

  # Suppress kernel info/debug messages from printing to TTY (avoids corrupting TUI greeters)
  boot.kernelParams = [ "loglevel=3" ];

  time.hardwareClockInLocalTime = true;

  networking.hostName = "fractal";
  # Enables DHCP on each ethernet and wireless interface
  networking.useDHCP = lib.mkDefault true;

  # SSH server
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
