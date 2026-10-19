{ forAllUsers, ... }:

{
  home-manager.users = forAllUsers { imports = [ ./hm.nix ]; };
}
