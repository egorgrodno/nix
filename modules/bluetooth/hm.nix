{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bluez
    bluez-tools

    # As the bar's switch: off soft-blocks every Bluetooth radio. BlueZ powers
    # an adapter the unblock brings back, so bton powers only one already there.
    (writeShellScriptBin "bton" ''
      rfkill unblock bluetooth
      if [ -n "$(ls /sys/class/bluetooth 2>/dev/null)" ]; then
        bluetoothctl -- power on
      fi
    '')
    (writeShellScriptBin "btoff" "rfkill block bluetooth")
  ];
}
