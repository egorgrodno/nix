{ pkgs, username, theme, ... }:

{
  home-manager.users.${username} = {
    home.packages = [
      (pkgs.writeScriptBin "dmenu" ''
        ${pkgs.dmenu}/bin/dmenu -nf '${theme.foreground.main}' -nb '${theme.background.light}' -sb '${theme.yellow}' -sf '${theme.background.main}' -fn '${theme.fontFamily}-13' "$@"
      '')
    ];
  };
}
