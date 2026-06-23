{ pkgs, forAllUsers, ... }:

{
  imports = [
    ./role-base-config.nix
    ./role-network-config.nix
    ./role-locale-config.nix
    ./role-devtools.nix
    ./role-nextcloud-client.nix
    ./role-print.nix
    ./role-vm-host.nix
    ../modules/desktop-x11
  ];

  base = {
    isNixosSystem = true;
    isDesktop = true;
    keyboard.layout = "hallmack";
  };

  my.desktop = {
    enable = true;
    primaryScreen = "DP-0";
    wallpaper = ../assets/orcas-2560-1440.jpg;
  };

  security.sudo.wheelNeedsPassword = false;

  users.users = forAllUsers (u: {
    isNormalUser = true;
    home = u.homedir;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "sound" "lp" ];
  });

  environment.systemPackages = with pkgs; [
    netdiscover
    usbutils
    nfs-utils
    cifs-utils
  ];
}
