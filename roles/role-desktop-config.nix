{ pkgs, lib, forAllUsers, ... }:

{
  imports = [
    ./role-base-config.nix
    ./role-network-config.nix
    ./role-locale-config.nix
    ./role-devtools.nix
    ./role-print.nix
    ../modules/desktop
  ];

  base = {
    isNixosSystem = true;
    isDesktop = true;
    # The layout is the author's preference, not a property of the stack, so a
    # host or a second account can pick qwerty without reaching for mkForce.
    keyboard.layout = lib.mkDefault "hallmack";
  };

  # Enable only; the screens are hardware, so each host sets its own
  # `my.desktop.*`.
  my.desktop.enable = true;

  security.sudo.wheelNeedsPassword = false;

  # `wheel` is opt-in per user through `admin` in users/*.nix, because sudo here
  # needs no password. A user file that omits the field stays unprivileged.
  users.users = forAllUsers (u: {
    isNormalUser = true;
    home = u.homedir;
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "audio" "sound" "lp" "video" ]
      ++ lib.optional (u.admin or false) "wheel";
  });

  environment.systemPackages = with pkgs; [
    netdiscover
    usbutils
    nfs-utils
    cifs-utils
  ];

  programs.nix-ld.enable = true;
}
