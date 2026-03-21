{ pkgs, config, ... }:

{
  home.packages = [ pkgs.ripgrep ];

  home.sessionVariables.RIPGREP_CONFIG_PATH = "${config.xdg.configHome}/ripgrep/.ripgreprc";

  xdg.configFile."ripgrep/.ripgreprc".text = ''
    --type-add
    js:*.{cjs,mjs}

    --type-add
    lq:*.{liquid,json,html,js,css}
  '';
}
