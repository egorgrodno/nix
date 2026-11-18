{ forAllUsers, ... }:

{
  # Its Include in /etc/ssh/ssh_config names a store file, which ssh refuses in
  # the Claude Code sandbox for the reason hm.nix copies ~/.ssh/config.
  programs.ssh.systemd-ssh-proxy.enable = false;

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
