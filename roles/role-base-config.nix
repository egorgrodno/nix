{ config, lib, ... }:

with lib;

let
  cfg = config.base;

in {
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
        type = types.enum [ "qwerty" "hallmack" ];
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
    assertions = [
      {
        assertion = cfg.isDesktop != cfg.isHeadless;
        message = "Either 'isDesktop' or 'isHeadless' must be enabled";
      }
    ];
  };
}
