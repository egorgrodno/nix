{ lib, users, ... }:

{
  virtualisation.docker = {
    enable = true;
    # docker.socket still raises the daemon on the first client connection, so a
    # bare `docker` command works without starting the service by hand.
    enableOnBoot = false;
  };

  # The daemon runs as root and its socket accepts a bind mount of any path, so
  # `docker` is root-equivalent. It follows `admin` for that reason, like `wheel`.
  users.extraGroups.docker.members = map (u: u.name) (lib.filter (u: u.admin or false) users);
}
