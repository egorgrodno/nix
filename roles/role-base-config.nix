{ config, lib, ... }:

with lib;

let
  cfg = config.base;

in
{
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
    ];

    home-manager.extraSpecialArgs = {
      keyboardLayout = cfg.keyboard.layout;
      isDesktop = cfg.isDesktop;
    };
  };
}
