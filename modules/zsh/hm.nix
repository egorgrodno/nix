{ config, keyboardLayout, isDesktop, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "viins";

    history = {
      path = "${config.home.homeDirectory}/.local/share/zsh/zsh_history";
      ignorePatterns = [ "*rm *" "*kill *" "*pkill *" "*shutdown*" "*reboot*" "*git *" "*vi*" "*cd *" ];
      ignoreDups = true;
      ignoreSpace = true;
    };

    shellGlobalAliases =
      let
        ls = "ls --group-directories-first --color=auto";
      in {
        inherit ls;
        ll = "${ls} -Alh";
        y = if isDesktop then "wl-copy" else "xclip -selection c";
      };

    initContent = import ./init-config.nix {
      config = { base.keyboard.layout = keyboardLayout; };
    };

    profileExtra = if isDesktop then ''
      if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
        exec Hyprland
      fi
    '' else "";
  };
}
