{ pkgs, username, ... }:

with builtins;

let
  homeDirectory = "/home/${username}";

in
{
  imports = [
    ./modules/desktop
    ./pkgs/git
    ./pkgs/shell-scripts
    ./pkgs/neovim
    ./pkgs/st
    ./pkgs/zsh
  ];

  time.timeZone = "Europe/Amsterdam";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings.LC_COLLATE = "C";
  };

  security.sudo.wheelNeedsPassword = false;

  networking.networkmanager.enable = true;

  sound.enable = true;
  hardware.bluetooth.enable = true;
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
    extraModules = [ pkgs.pulseaudio-modules-bt ];
  };

  users.users.${username} = {
    isNormalUser = true;
    home = homeDirectory;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "sound" "pulse" ];
  };

  desktop = {
    enable = true;
    wallpaper = ./assets/wallpaper.png;
    hallmack = true;
  };

  environment.systemPackages = with pkgs; [
    dconf
    gcc
    git
    htop
    unzip
    wget
    xclip
    zip
  ];

  services.dbus.packages = [ pkgs.gnome3.dconf ];

  home-manager.users.${username} = {
    programs.home-manager.enable = true;

    home = {
      inherit username homeDirectory;
      stateVersion = "22.05";
    };
  };
}
