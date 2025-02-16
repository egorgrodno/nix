{ pkgs, username, homedir, ... }:

with builtins;

{
  imports = [
    ./modules/git.nix
    ./modules/zsh.nix
    ./modules/less.nix
    ./modules/nixtools.nix
    ./modules/ripgrep.nix
    ./modules/devtools.nix
    ./modules/extools.nix
    ./modules/neovim

    ./modules/desktop.nix
    ./modules/st
  ];

  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";

  security.sudo.wheelNeedsPassword = false;

  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
    # extraHosts = ''
    # '';
  };

  users.users.${username} = {
    isNormalUser = true;
    home = homedir;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "sound" "lp" ];
  };

  desktop = {
    enable = true;
    wallpaper = ./assets/orcas-2560-1440.jpg;
    primaryScreen = "DP-0";
    hallmack = true;
  };
  my.bluetooth.enable = true;

  environment.systemPackages = with pkgs; [
    dconf
    fd
    gcc
    git
    htop
    ripgrep
    unzip
    wget
    xclip
    zip
    file
  ];

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ username ];

  services.dbus.packages = [ pkgs.dconf ];

  home-manager.users.${username} = {
    programs.home-manager.enable = true;

    home = {
      inherit username;
      homeDirectory = homedir;
      stateVersion = "22.05";
    };
  };
}
