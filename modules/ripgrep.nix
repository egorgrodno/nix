{ pkgs, username, homedir, ... }:

{
  environment.variables.RIPGREP_CONFIG_PATH = "${homedir}/.config/ripgrep/.ripgreprc";

  home-manager.users.${username} = {
    home.packages = [ pkgs.ripgrep ];

    xdg.configFile."ripgrep/.ripgreprc".text = ''
      --type-add
      js:*.{cjs,mjs}

      --type-add
      lq:*.{liquid,json,html,js,css}
    '';
  };
}
