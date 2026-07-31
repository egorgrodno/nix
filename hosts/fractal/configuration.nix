{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
    # ../../roles/role-nextcloud-client.nix
    # ../../roles/role-vm-host.nix
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

  time.hardwareClockInLocalTime = true;

  networking.hostName = "fractal";
  networking.useDHCP = lib.mkDefault true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  system.stateVersion = "24.11";
}
