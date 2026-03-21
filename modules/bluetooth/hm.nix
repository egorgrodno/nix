{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bluez
    bluez-tools

    (writeShellScriptBin "bton" ''
      systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service
      bluetoothctl -- power on
    '')
    (writeShellScriptBin "btoff" "bluetoothctl -- power off")
  ];
}
