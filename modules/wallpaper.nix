{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.wallpaper;
in
  {
    options.wallpaper = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };

      path = mkOption {
        type = types.path;
        description = "wallpaper path";
      };
    };

    config = mkIf cfg.enable {
      environment.systemPackages = [ pkgs.feh ];

      environment.variables =
        { WALLPAPER = toString cfg.path;
        };
    };
  }
