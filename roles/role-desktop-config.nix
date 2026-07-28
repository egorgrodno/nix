{ pkgs, forAllUsers, ... }:

{
  imports = [
    ./role-base-config.nix
    ./role-network-config.nix
    ./role-locale-config.nix
    ./role-devtools.nix
    # ./role-nextcloud-client.nix
    ./role-print.nix
    # ./role-vm-host.nix
    ../modules/desktop
  ];

  base = {
    isNixosSystem = true;
    isDesktop = true;
    keyboard.layout = "hallmack";
  };

  # The screen layout is hardware, so every host sets its own `my.desktop.*`
  # options.
  my.desktop.enable = true;

  security.sudo.wheelNeedsPassword = false;

  users.users = forAllUsers (u: {
    isNormalUser = true;
    home = u.homedir;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "sound" "lp" "video" ];
  });

  environment.systemPackages = with pkgs; [
    netdiscover
    usbutils
    nfs-utils
    cifs-utils
  ];

  programs.nix-ld.enable = true;
}
