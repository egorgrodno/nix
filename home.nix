{ users, ... }:

let
  mkUserHome = u: {
    name = u.name;
    value = {
      imports = u.homeModules or [];
      programs.home-manager.enable = true;

      home = {
        username = u.name;
        homeDirectory = u.homedir;
        stateVersion = u.stateVersion;
      };
    };
  };
in
{
  home-manager.users = builtins.listToAttrs (map mkUserHome users);
}
