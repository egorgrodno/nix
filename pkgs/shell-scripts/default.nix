{ pkgs, ... }:

let
  btConnect = mac: "bluetoothctl -- connect ${mac}";
  shellScripts = [
    {
      name = "nxu";
      script = "nix flake update --flake /etc/nixos";
    }
    {
      name = "nxs";
      script = "nixos-rebuild switch --flake /etc/nixos";
    }
    {
      name = "nxb";
      script = "nixos-rebuild build --flake /etc/nixos";
    }
    {
      name = "nxt";
      script = "nixos-rebuild test --flake /etc/nixos";
    }
    {
      name = "dp";
      script = "xrandr --output DP-1 --primary --auto --output HDMI-1 --off --output eDP-1 --off && wallpaper-reset";
    }
    {
      name = "edp";
      script = "xrandr --output eDP-1 --primary --auto --output HDMI-1 --off --output DP-1 --off && wallpaper-reset";
    }
    {
      name = "hdmi";
      script = "xrandr --output HDMI-1 --primary --auto --output eDP-1 --off --output DP-1 --off && wallpaper-reset";
    }
    {
      name = "bt-on";
      script = ''
        systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service
        bluetoothctl -- power on
      '';
    }
    {
      name = "bt-off";
      script = "bluetoothctl -- power off";
    }
    {
      name = "bt-connect-sony";
      script = btConnect "14:3F:A6:A8:73:D7";
    }
    {
      name = "bt-connect-jbl";
      script = btConnect "F8:5C:7D:94:22:E8";
    }
  ];
in
{
  environment.systemPackages =
    map ({ name, script }: pkgs.writeShellScriptBin name script) shellScripts;
}
