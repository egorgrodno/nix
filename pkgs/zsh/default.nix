{ config, pkgs, username, ... }:

{
  environment = {
    variables.KEYTIMEOUT = "1";
    pathsToLink = [ "/share/zsh" ];
  };

  home-manager.users.${username} = {
    programs.zsh =
      let
        options = [
          "HIST_IGNORE_ALL_DUPS"
          "HIST_REDUCE_BLANKS"
          "INC_APPEND_HISTORY"
          "PROMPT_SUBST"
        ];

      in
      {
        enable = true;
        enableCompletion = true;
        enableAutosuggestions = true;
        enableSyntaxHighlighting = true;
        dotDir = ".config/zsh";
        defaultKeymap = "viins";

        history = {
          path = ".local/share/zsh/zsh_history";
          ignorePatterns = [ "*rm *" "*kill *" "*pkill *" ];
          ignoreDups = true;
          ignoreSpace = true;
        };

        shellGlobalAliases =
          let
            ls = "ls --group-directories-first --color=auto";
          in
          {
            inherit ls;
            ll = "${ls} -alh";
            y = "xclip -selection c";
          };

        profileExtra = ''
          if [[ -z $DISPLAY ]] && [[ $XDG_VTNR -eq 1 ]]; then
            exec startx
          fi
        '';

        initExtra = ''
          # Left prompt
          if [[ $UID == 0 || $EUID == 0 ]]; then
            PROMPT_BASE="%F{1}%3~ %(1j.%j .)#%f"
          else
            PROMPT_BASE="%F{3}%3~ %(1j.%F{1}%j .)%F{4}$%f"
          fi

          function set-prompt {
            case $KEYMAP in
              (vicmd)       VI_MODE="%F{12}[N]" ;;
              (main|viins)  VI_MODE="%F{8}[I]" ;;
              (*)           VI_MODE="[ ]" ;;
            esac

            PROMPT=" $VI_MODE $PROMPT_BASE "
          }

          function zle-keymap-select zle-line-init {
            set-prompt
            zle reset-prompt
          }

          zle -N zle-line-init
          zle -N zle-keymap-select

          # Right prompt

          autoload -Uz vcs_info
          zstyle ":vcs_info:git*" formats "%F{5}%s%f:%F{2}%b%f"
          precmd() {
            vcs_info
            print ""
          }
          RPROMPT=' ''${vcs_info_msg_0_} %?'

          ${builtins.concatStringsSep "\n" (map (x: "setopt " + x) options)}

          bindkey -s "^Z" "fg\n"

          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        '';
      };
  };
}
