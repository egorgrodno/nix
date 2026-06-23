{ forAllUsers, ... }:

{
  # ccusage (Claude Code statusline) uses /tmp/ccusage-semaphore/ for session locking.
  # Without this, whichever user runs it first owns the directory (mode 755) and
  # blocks all other users from creating their lock files.
  systemd.tmpfiles.rules = [
    "d /tmp/ccusage-semaphore 1777 root root -"
  ];

  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
