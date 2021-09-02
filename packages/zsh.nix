{ pkgs, lib, ... }:

with lib;

{
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = [ pkgs.zsh ];

  environment.variables =
    { KEYTIMEOUT     = "1";
      ZDOTDIR        = "$HOME/.config/zsh";
      HISTORY_IGNORE = concatStringsSep ":" ["*rm *" "*pkill *"];
    };

  homefiles.file.zshrc =
    { path = ".config/zsh/.zshrc";
      content =
        ''
          HISTFILE="$ZDOTDIR/.zsh_history"
        '';
    };

  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 20000;

    setOptions =
      [ # Prevents aliases on the command line from being internally substituted
        # before completion is attempted. The effect is to make the alias a
        # distinct command for completion purposes.
        "COMPLETE_ALIASES"

        # If a new command line being added to the history list duplicates an
        # older one, the older command is removed from the list (even if it is
        # not the previous event).
        "HIST_IGNORE_ALL_DUPS"

        # Do not enter command lines into the history list if they are
        # duplicates of the previous event.
        "HIST_IGNORE_DUPS"

        # Remove command lines from the history list when the first character on
        # the line is a space, or when one of the expanded aliases contains a 
        # eading space. Only normal aliases (not global or suffix aliases) have
        # this behaviour. Note that the command lingers in the internal history
        # until the next command is entered before it vanishes, allowing you to
        # briefly reuse or edit the line. If you want to make it vanish right
        # away without entering another command, type a space and press return.
        "HIST_IGNORE_SPACE"

        # Remove superfluous blanks from each command line being added to the
        # history list.
        "HIST_REDUCE_BLANKS"

        # This option works like APPEND_HISTORY except that new history lines
        # are added to the $HISTFILE incrementally (as soon as they are
        # entered), rather than waiting until the shell exits. The file will
        # still be periodically re-written to trim it when the number of lines
        # grows 20% beyond the value specified by $SAVEHIST (see also the
        # HIST_SAVE_BY_COPY option).
        "INC_APPEND_HISTORY"

        # Parameter expansion, command substitution and arithmetic expansion are
        # performed in prompts. Substitutions within prompts do not affect the
        # command status.
        "PROMPT_SUBST"
      ];

    interactiveShellInit =
      ''
        bindkey -s "^Z" "fg\n"
      '';

    promptInit =
      ''
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
        precmd() { vcs_info }
        RPROMPT=' ''${vcs_info_msg_0_} %?'
      '';
  };
}
