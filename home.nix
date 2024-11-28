{ pkgs, username, homedir, ... }:

with builtins;

{
  imports = [
    ./modules/desktop.nix
    ./pkgs/git.nix
    ./pkgs/less.nix
    ./pkgs/neovim
    ./pkgs/ripgrep.nix
    ./pkgs/shell-scripts.nix
    ./pkgs/st
    ./pkgs/zsh.nix
  ];

  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";

  security.sudo.wheelNeedsPassword = false;

  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
    extraHosts = "
      127.0.0.1 remarq
      87.213.229.227 gigaio2
    ";
  };

  sound.enable = true;
  hardware.bluetooth.enable = true;
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  users.users.${username} = {
    isNormalUser = true;
    home = homedir;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "audio" "sound" "pulse" ];
  };

  desktop = {
    enable = true;
    wallpaper = ./assets/orcas-2560-1440.jpg;
    hallmack = true;
  };

  environment.systemPackages = with pkgs; [
    dconf
    fd
    gcc
    git
    htop
    postgresql
    ripgrep
    unzip
    wget
    xclip
    zip
    file
  ];

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ username ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    dataDir = "/data/postgresql";
  };

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
