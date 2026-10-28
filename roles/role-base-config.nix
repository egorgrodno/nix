{ config, lib, ... }:

with lib;

let
  cfg = config.base;

in
{
  imports = [ ./role-laptop.nix ];

  options.base = {
    isNixosSystem = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the configuration is being evaluated on a NixOS system";
    };

    isDesktop = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the configuration is being evaluated on a system with a desktop GUI";
    };

    isHeadless = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the configuration is being evaluated on a headless system";
    };

    isLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the machine is a laptop: turns on `role-laptop.nix` and pins the chassis hostnamed reports";
    };

    hibernate = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the machine hibernates, which takes swap at least the size of RAM: a suspend from idle, the lid or the session menu hibernates after HibernateDelaySec, and the session menu offers hibernation";
    };

    bosun = {
      sleepLock = mkOption {
        type = types.enum [
          "on"
          "off"
          "battery"
        ];
        default = "on";
        description = "Whether bosun's daemon holds a logind sleep lock while a session other than the desk works: `battery` holds it only while a battery discharges";
      };

      sleepLockQuiet = mkOption {
        type = types.str;
        default = "10m";
        description = "How long no session works before bosun's daemon releases the sleep lock, as a Go duration";
      };
    };

    keyboard = {
      layout = mkOption {
        type = types.enum [
          "qwerty"
          "hallmack"
        ];
        description = "Keyboard layout";
      };

      swapCapsEscape = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to swap CapsLock and Escape keys";
      };
    };
  };

  config = {
    boot.tmp.cleanOnBoot = true;

    # A generation survives while it is one of the last 10 or under 90 days old,
    # so a quiet spell never strips the rollback history.
    programs.nh.clean = {
      enable = true;
      extraArgs = "--keep 10 --keep-since 90d";
    };
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    # NIXBOOT is 1 GiB, and every distinct kernel copies about 70 MB onto it.
    boot.loader.grub.configurationLimit = 20;

    # Every host is partitioned to these labels, which is what lets the installer
    # and repair-boot mount any of them without asking.
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    assertions = [
      {
        assertion = cfg.isDesktop != cfg.isHeadless;
        message = "Either 'isDesktop' or 'isHeadless' must be enabled";
      }
      # logind refuses to hibernate without swap, leaving the machine awake.
      {
        assertion = cfg.hibernate -> config.swapDevices != [ ];
        message = "`base.hibernate` hibernates to swap: declare swap at least the size of RAM in `swapDevices`.";
      }
    ];

    systemd.sleep.settings.Sleep.HibernateDelaySec = mkIf cfg.hibernate "10min";

    # Read by tools that act only on a laptop, such as dev mode's inhibitor.
    environment.etc."machine-info" = mkIf (cfg.isLaptop || cfg.isDesktop) {
      text = "CHASSIS=${if cfg.isLaptop then "laptop" else "desktop"}\n";
    };

    home-manager.extraSpecialArgs = {
      keyboardLayout = cfg.keyboard.layout;
      isDesktop = cfg.isDesktop;
      bosunSleepLock = cfg.bosun.sleepLock;
      bosunSleepLockQuiet = cfg.bosun.sleepLockQuiet;
    };
  };
}
