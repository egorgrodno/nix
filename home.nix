{ username, homedir, ... }:

{
  home-manager.users.${username} = {
    programs.home-manager.enable = true;

    home = {
      inherit username;
      homeDirectory = homedir;
      stateVersion = "22.05";
    };
  };
}
