{ pkgs, ... }:

{ services.xserver =
    { enable = true;
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
          extraPackages = with pkgs; [
            dmenu i3status i3lock
          ];
        };
    };

  environment.etc =
    let
      mkFile = filename: content: {
        "home/${filename}" =
          { mode = "0444";
            text =
              ''
                # /etc/home/${filename}: DO NOT EDIT -- this file has been generated automatically.

                ${content}
              '';
          };
      };

      xinitrc = mkFile "xinitrc"
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
            feh --no-fehbg --bg-scale $WALLPAPER
          fi

          exec i3 --shmlog-size 0
        '';

      profile = mkFile "profile"
        ''
          if [[ -z $DISPLAY ]] && [[ $XDG_VTNR -eq 1 ]]; then
            exec startx
          fi
        '';

    in (xinitrc // profile);
}
