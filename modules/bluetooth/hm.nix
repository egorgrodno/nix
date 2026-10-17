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

  # The applet runs only under blueman-manager, for its pairing agent, and the
  # bar's module already shows Bluetooth. Without its StatusNotifierItem the
  # applet falls back to GtkStatusIcon, which draws nothing on Wayland.
  dconf.settings."org/blueman/general".plugin-list = [ "!StatusNotifierItem" ];
}
