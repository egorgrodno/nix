{ users, ... }:

{
  home-manager.users = builtins.listToAttrs (map (u: {
    name = u.name;
    value = { imports = [ ./hm.nix ]; };
  }) users);
}
