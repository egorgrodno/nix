{ config, lib, forAllUsers, ... }:

let cfg = config.my.bluetooth;

in {
  options.my.bluetooth.enable = lib.mkEnableOption "Enable bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;

    home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
  };
}
