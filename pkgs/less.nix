{ config, pkgs, username, theme, ... }:

{
  home-manager.users.${username} = {
    programs.less = {
      enable = true;
      keys = if config.desktop.hallmack then ''
        e back-line
        E back-line-force
        a forw-line
        A forw-line-force
      '' else "";
    };
  };
}
