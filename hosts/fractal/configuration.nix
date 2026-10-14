{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Both variables below take a colon-separated list, which rules out the
  # `by-path` node whose own name contains colons; `cardN` numbering follows
  # enumeration order and shifts between boots. Hence the udev symlink.
  discreteGpu = "/dev/dri/nvidia-card";
in

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
    ../../roles/role-nextcloud-client.nix
    ../../roles/role-docker.nix
    # ../../roles/role-vm-host.nix
  ];

  my.desktop = {
    primaryScreen = "HDMI-A-2";
    primaryMode = "2560x1440@120";
  };

  # NVIDIA on a hybrid AMD/NVIDIA board. No `prime`: it emits Xorg
  # provider-offload configuration, and no Xorg runs here. `AQ_DRM_DEVICES`
  # below is what confines the session to the discrete card.
  services.xserver.videoDrivers = [ "nvidia" ]; # still the driver knob under Wayland
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true; # Recommended for 40-series cards
    modesetting.enable = true;
    powerManagement.enable = true;
  };
  boot.blacklistedKernelModules = [ "nouveau" ];
  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];

  # DEVNAME because the connector devices under this card are also `card*`, and
  # an exact ID_PATH because the boot framebuffer hangs off the same PCI address
  # with a longer one.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ENV{DEVNAME}=="/dev/dri/card*", ENV{ID_PATH}=="pci-0000:01:00.0", SYMLINK+="dri/nvidia-card"
  '';

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Unpinned, aquamarine renders on the Raphael iGPU and copies every frame
    # across PCIe to the card that drives HDMI-A-2, which speckles the screen
    # with artifacts. The cost of the pin: the board's own outputs go dark.
    AQ_DRM_DEVICES = discreteGpu;
    # The greeter's cage is wlroots, not aquamarine, so the same pin arrives a
    # second time under wlroots' name. It belongs here rather than on
    # greetd.service: greetd builds the greeter's environment from PAM, which
    # reads these, and discards its own.
    WLR_DRM_DEVICES = discreteGpu;
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

  # Sized to RAM so any workload fits the hibernation image. systemd records the
  # file's location in the HibernateLocation EFI variable and the systemd initrd
  # resumes from it, so neither `resume=` nor `resume_offset=` is set.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
    }
  ];

  time.hardwareClockInLocalTime = true;

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
