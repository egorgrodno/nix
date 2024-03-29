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
    wallpaper = ./assets/wallpaper.png;
    hallmack = true;
  };

  environment.systemPackages = with pkgs; [
    dconf
    fd
    gcc
    git
    htop
    postgresql
    unzip
    wget
    xclip
    zip
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
