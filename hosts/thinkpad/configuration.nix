{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
    # ../../roles/role-nextcloud-client.nix
    # ../../roles/role-vm-host.nix
  ];

  base.isLaptop = true;

  base.keyboard = {
    layout = "qwerty";
    swapCapsEscape = true;
  };

  # Wifi and Bluetooth firmware, and the AMD microcode the hardware file wires up.
  hardware.enableRedistributableFirmware = true;

  # The TrackPoint buttons reach libinput as a device apart from the touchpad,
  # so a finger brushing the pad while it holds one turns a drag into a
  # two-finger scroll. A top button strip keeps touches that start in the top
  # 10 mm out of pointer motion and gestures.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [ThinkPad T14 Gen 5 touchpad]
    MatchUdevType=touchpad
    MatchName=SYNA8019:00 06CB:CE68 Touchpad
    AttrInputProp=+INPUT_PROP_TOPBUTTONPAD
  '';

  environment.systemPackages = [
    # Rebinding the driver resets the touchpad, which recalibrates it. One
    # touched while it resumes can lose its left click until then.
    (pkgs.writeShellScriptBin "touchpad-reset" ''
      driver=/sys/bus/i2c/drivers/i2c_hid_acpi
      echo i2c-SYNA8019:00 | sudo tee $driver/unbind >/dev/null
      sleep 1
      echo i2c-SYNA8019:00 | sudo tee $driver/bind >/dev/null
    '')
    # Reloading the driver resets the Wi-Fi card. ath11k can stop completing
    # WPA handshakes, associating and then timing out, until then.
    (pkgs.writeShellScriptBin "wifi-reset" ''
      sudo modprobe -r ath11k_pci
      sleep 1
      sudo modprobe ath11k_pci
    '')
  ];

  boot.loader = {
    efi.canTouchEfiVariables = false;
    # The hidden menu opens on F4 only while GRUB polls through this timeout:
    # at zero it polls once, and this firmware never reports a lone Shift.
    timeout = 1;
    grub = {
      enable = true;
      device = "nodev";
      useOSProber = false;
      efiSupport = true;
      efiInstallAsRemovable = true;
      timeoutStyle = "hidden";
    };
  };

  # The Phoenix display microcontroller (DMCUB) hung in the eDP panel's Panel
  # Self Refresh and froze the session (egor/nix#131). 0x10 is DC_DISABLE_PSR,
  # which covers PSR1 and PSR-SU; 0x400 is DC_DISABLE_REPLAY, since Panel Replay
  # is a separate DMCUB path that DCN 3.1.4 enables by default.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x410" ];

  # 176 is sync (16) + remount read-only (32) + reboot (128), so a hang can end
  # with Alt+SysRq S, U, B and keep the journal's last lines.
  boot.kernel.sysctl."kernel.sysrq" = 176;

  base.hibernate = true;

  # Sized to RAM so any workload fits the hibernation image. systemd records the
  # file's location in the HibernateLocation EFI variable and the systemd initrd
  # resumes from it, so neither `resume=` nor `resume_offset=` is set.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
    }
  ];

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
