{ forAllUsers, ... }:

{
  # The machine's layout, which `kb-layout` writes from any account.
  systemd.tmpfiles.rules = [ "f /var/lib/keyboard-layout 0664 root users -" ];

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
