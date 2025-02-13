{ config, lib, pkgs, username, ... }:

let cfg = config.my.bluetooth;

in {
  options.my.bluetooth.enable = lib.mkEnableOption "Enable bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;

    home-manager.users.${username} = {
      home.packages = with pkgs; [
        bluez
        bluez-tools

        (writeShellScriptBin "bton" ''
          systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service
          bluetoothctl -- power on
        '')
        (writeShellScriptBin "btoff" "bluetoothctl -- power off")
      ];
    };
  };
}
