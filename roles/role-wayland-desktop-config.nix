{ pkgs, users, ... }:

{
  imports = [
    ./role-base-config.nix
    ./role-network-config.nix
    ./role-locale-config.nix
    ./role-devtools.nix
    # ./role-nextcloud-client.nix
    ./role-print.nix
    # ./role-vm-host.nix
    ../modules/desktop-wayland
  ];

  base = {
    isNixosSystem = true;
    isDesktop = true;
    keyboard.layout = "hallmack";
  };

  desktop = {
    enable = true;
    primaryScreen = "DP-4";
    wallpaper = ../assets/orcas-2560-1440.jpg;
    monitors = [
      "DP-4, 2560x1440@165, 0x0, 1"
      "HDMI-A-2, 2560x1440@60, auto-left, 1.33, transform, 1"
      ", preferred, auto, 1"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  users.users = builtins.listToAttrs (map (u: {
    name = u.name;
    value = {
      isNormalUser = true;
      home = u.homedir;
      shell = pkgs.zsh;
      extraGroups = [ "wheel" "networkmanager" "audio" "sound" "lp" "video" ];
    };
  }) users);

  environment.systemPackages = with pkgs; [
    netdiscover
    usbutils
    nfs-utils
    cifs-utils
  ];

  programs.nix-ld.enable = true;
}
