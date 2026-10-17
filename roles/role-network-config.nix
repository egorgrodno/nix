{ pkgs, ... }:

{
  networking.firewall.enable = true;
  networking.networkmanager = {
    enable = true;
    # WireGuard is built in.
    plugins = [ pkgs.networkmanager-openvpn ];
  };
}
