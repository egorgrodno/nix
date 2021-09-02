{ lib, username, name, email, homefiles ? false, gitconfig ? false }:

with lib;

{
  users.users.${username} = {
    isNormalUser = true;
    description = name;
    home = "/home/${username}";

    extraGroups =
      [ "wheel"
        "networkmanager"
      ];
  };

  homefiles.users = lists.optional homefiles username;
  homefiles.file = mkIf gitconfig {
    gitconfig = {
      path = ".config/git/config";
      content =
        generators.toGitINI (import ./gitconfig.nix // {
          user = { inherit name email; };
        });
    };
  };
}
