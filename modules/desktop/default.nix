{ config, lib, pkgs, username, ... }:

with lib;

let
  cfg = config.desktop;
  resetWallpaper = "${pkgs.feh}/bin/feh --no-fehbg --bg-scale ${cfg.wallpaper}";
  theme = {
    fontFamily = "Inconsolata Nerd Font";
    background = {
      main = "#282C34";
      light = "#30343C";
    };
    foreground = {
      main = "#DCDFE4";
      dark = "#434956";
    };
    red = "#E06C75";
    green = "#98C379";
    yellow = "#E5C07B";
    blue = "#61AFEF";
    magenta = "#C678DD";
    cyan = "#56B6C2";
  };

in
{
  options.desktop = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    wallpaper = mkOption {
      type = types.path;
      description = "wallpaper path";
    };

    hallmack = mkOption {
      type = types.bool;
      default = false;
      description = "enable halmack layout";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      feh
      (writeShellScriptBin "wallpaper-reset" resetWallpaper)
    ];

    services.xserver = {
      enable = true;
      desktopManager.xterm.enable = false;
      autoRepeatDelay = 200;
      autoRepeatInterval = 30;
      layout = "us,ru";
      xkbOptions =
        if cfg.hallmack
        then "grp:win_space_toggle"
        else "grp:win_space_toggle,caps:swapescape";

      libinput = {
        enable = true;
        mouse.disableWhileTyping = true;
        touchpad = {
          tapping = false;
          middleEmulation = false;
          disableWhileTyping = true;
        };
      };

      displayManager = {
        startx.enable = true;
        defaultSession = "none+i3";
      };

      windowManager.i3 = {
        enable = true;
        package = pkgs.i3-gaps;
        extraPackages = with pkgs; [
          dmenu
          i3status
          i3lock
        ];
      };
    };

    fonts.fonts = [
      (pkgs.nerdfonts.override { fonts = [ "Inconsolata" ]; })
    ];

    home-manager.users.${username} = {
      home.packages = with pkgs; [
        shutter
        bluez
        bluez-tools
        chromium
        evince
        galculator
        libnotify
        pasystray
        pavucontrol
        pcmanfm
        picom
        postman
        simplescreenrecorder
        slack
        tdesktop
        transmission-gtk
        viewnior
        vlc
        xorg.xkill
        zoom-us
        networkmanagerapplet
      ];

      home.file.".xinitrc".text = ''
        if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
          eval $(dbus-launch --exit-with-session --sh-syntax)
        fi
        systemctl --user import-environment DISPLAY XAUTHORITY

        if command -v dbus-update-activation-environment >/dev/null 2>&1; then
          dbus-update-activation-environment DISPLAY XAUTHORITY
        fi

        ${resetWallpaper}

        exec i3 --shmlog-size 0
      '';

      xdg = {
        enable = true;

        mimeApps =
          let
            mkAssociation = app: mimeTypes:
              listToAttrs (map (mimeType: { name = mimeType; value = app; }) mimeTypes);
            magnetLink = mkAssociation "userapp-transmission-gtk-ULULF1.desktop" [ "x-scheme-handler/magnet" ];
            postmanLink = mkAssociation "Postman.desktop" [ "x-scheme-handler/postman" ];
            pdf = mkAssociation "org.gnome.Evince.desktop" [ "application/pdf" ];
            image = mkAssociation "viewnior.desktop" [ "image/gif" "image/jpeg" "image/png" "image/webp" ];
          in
          {
            enable = true;
            defaultApplications = image // pdf // magnetLink // postmanLink;
            associations.added = magnetLink;
          };
      };

      dconf = {
        enable = true;
        settings."org.gnome.desktop.wm.preferences".button-layout = "appmenu:close";
      };

      gtk = {
        enable = true;
        theme = {
          name = "Materia-light-compact";
          package = pkgs.materia-theme;
        };
        iconTheme = {
          name = "Papirus-Light";
          package = pkgs.papirus-icon-theme;
        };
      };

      xsession.pointerCursor = {
        name = "Numix-Cursor";
        package = pkgs.numix-cursor-theme;
      };

      services.dunst = {
        enable = true;

        settings = {
          global = {
            notification_limit = 5;
            font = "${theme.fontFamily} 11";
            background = theme.background.light;
            foreground = theme.foreground.main;
            width = "(200, 500)";
            offset = "30x30";
            padding = 12;
            horizontal_padding = 14;
            frame_width = 2;
          };

          urgency_low = {
            frame_color = theme.foreground.dark;
            timeout = 5;
          };

          urgency_normal = {
            frame_color = theme.blue;
            timeout = 15;
          };

          urgency_critical = {
            frame_color = theme.red;
            timeout = 0;
          };
        };
      };
    };
  };
}
