{ pkgs, lib, ... }:

{
  imports =
    [ ../packages/dmenu-history.nix
    ];

  services.xserver = {
    enable = true;
    desktopManager.xterm.enable = false;
    autoRepeatDelay = 200;
    autoRepeatInterval = 30;
    layout = "us,ru";
    xkbOptions = "grp:win_space_toggle,caps:swapescape";

    displayManager =
      { startx.enable = true;
        defaultSession = "none+i3";
      };

    windowManager.i3 =
      { enable = true;
        package = pkgs.i3-gaps;
        extraPackages =
          with pkgs;
          [ dmenu
            i3status
            i3lock
          ];
      };
  };

  homefiles = {
    enable = lib.mkForce true;

    file.initrc =
      { path = ".xinitrc";
        content =
          ''
            [ -f ~/.profile ] && . ~/.profile

            if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
              eval $(dbus-launch --exit-with-session --sh-syntax)
            fi
            systemctl --user import-environment DISPLAY XAUTHORITY

            if command -v dbus-update-activation-environment >/dev/null 2>&1; then
              dbus-update-activation-environment DISPLAY XAUTHORITY
            fi

            if [[ -f $WALLPAPER ]]; then
              feh --no-fehbg --bg-fill $WALLPAPER
            fi

            exec i3 --shmlog-size 0
          '';
      };

    file.zprofile =
      { path = ".config/zsh/.zprofile";
        content =
          ''
            if [[ -z $DISPLAY ]] && [[ $XDG_VTNR -eq 1 ]]; then
              exec startx
            fi
          '';
      };

    file.i3-config =
      { path = ".config/i3/config";
        content = builtins.readFile ./i3-config;
      };

    file.i3status-config =
      { path = ".config/i3status/config";
        content = builtins.readFile ./i3status-config;
      };
  };
}
