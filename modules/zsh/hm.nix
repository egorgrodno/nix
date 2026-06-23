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

    initContent =
      (import ./init-config.nix {
        config = { base.keyboard.layout = keyboardLayout; };
      })
      # Inside a kitty window, use the ssh kitten (it copies terminfo and shell
      # integration to the remote); everywhere else — e.g. under `sudo su`, where
      # kitty's environment is stripped — fall back to the real ssh binary.
      + (if isDesktop then ''

        ssh() {
          if [[ -n $KITTY_WINDOW_ID ]]; then
            kitten ssh "$@"
          else
            command ssh "$@"
          fi
        }
      '' else "");

    profileExtra = if isDesktop then ''
      if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
        exec Hyprland
      fi
    '' else "";
  };
}
