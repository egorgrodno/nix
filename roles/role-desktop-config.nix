{ pkgs, username, homedir, ... }:

{
  imports = [
    ./role-base-config.nix
    ./role-network-config.nix
    ./role-locale-config.nix
    ./role-devtools.nix
    ./role-nextcloud-client.nix
    ./role-print.nix
    ./role-vm-host.nix
    ../modules/desktop
  ];

  base.isNixosSystem = true;
  base.isDesktop = true;
  base.keyboard.layout = "qwerty";
  base.keyboard.swapCapsEscape = true;

  desktop = {
    enable = true;
    wallpaper = ../assets/orcas-2560-1440.jpg;
    primaryScreen = "HDMI-0";
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.${username} = {
    isNormalUser = true;
    home = homedir;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "sound" "lp" ];
  };

  environment.systemPackages = with pkgs; [
    netdiscover
    usbutils
    nfs-utils
    cifs-utils
  ];
}
