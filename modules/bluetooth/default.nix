{
  config,
  lib,
  forAllUsers,
  ...
}:

let
  cfg = config.my.bluetooth;

in
{
  options.my.bluetooth.enable = lib.mkEnableOption "Enable bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;

    # The bar's Bluetooth module stands in for the tray applet, which
    # blueman-manager starts over D-Bus while it is open, for its pairing agent.
    services.blueman.enable = true;

    home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
  };
}
