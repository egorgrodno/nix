{
  config,
  pkgs,
  forAllUsers,
  ...
}:

with pkgs;

let
  systemPackages = [
    wget
    htop
    zip
    unzip
    file
  ];
in
{
  environment.systemPackages = if config.base.isNixosSystem then systemPackages else [ ];

  # Its Include in /etc/ssh/ssh_config names a store file, which ssh refuses in
  # the Claude Code sandbox for the reason hm.nix copies ~/.ssh/config.
  programs.ssh.systemd-ssh-proxy.enable = false;

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
