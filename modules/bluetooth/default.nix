{ config, lib, users, ... }:

let cfg = config.my.bluetooth;

in {
  options.my.bluetooth.enable = lib.mkEnableOption "Enable bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;

    home-manager.users = builtins.listToAttrs (map (u: {
      name = u.name;
      value = { imports = [ ./hm.nix ]; };
    }) users);
  };
}
