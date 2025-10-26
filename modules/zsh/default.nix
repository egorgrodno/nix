{ config, lib, username, homedir, ... }:

with lib;

let
  cfg = config.zsh;

in {
  options.zsh.enable = mkEnableOption "zsh shell";

  config = mkIf cfg.enable {
    environment = {
      variables.KEYTIMEOUT = "1";
      pathsToLink = [ "/share/zsh" ];
    };

    programs.zsh.enable = true;
    programs.zsh.autosuggestions.enable = true;

    home-manager.users.${username} = {

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
        dotDir = ".config/zsh";
        defaultKeymap = "viins";

        history = {
          path = "${homedir}/.local/share/zsh/zsh_history";
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
            y = "xclip -selection c";
          };

        profileExtra = if config.base.isDesktop then ''
        if [[ -z $DISPLAY ]] && [[ $XDG_VTNR -eq 1 ]]; then
          exec startx
        fi
        '' else "";

        initExtra = import ./init-config.nix { inherit config; };
      };
    };
  };
}
