{ config, lib, pkgs, username, theme, ... }:

with lib;

let
  cfg = config.desktop;
  resetWallpaper = "${pkgs.feh}/bin/feh --no-fehbg --bg-scale ${cfg.wallpaper}";
  dp = ''
    xrandr --output DP-1 --primary --auto --output HDMI-1 --off --output eDP-1 --off
    ${resetWallpaper}
  '';
  edp = ''
    xrandr --output eDP-1 --primary --auto --output HDMI-1 --off --output DP-1 --off
    ${resetWallpaper}
  '';
  hdmi = ''
    xrandr --output HDMI-1 --primary --auto --output eDP-1 --off --output DP-1 --off
    ${resetWallpaper}
  '';
  autoScreen = ''
    if [ -n "$(xrandr | rg '^HDMI-1 connected')" ]; then
      ${hdmi}
    else
      ${edp}
    fi
  '';
  i3Kill = ''
    DMENU_OUT=$(dmenu -p "Kill:" < /dev/null)

    if [[ -z "$DMENU_OUT" ]]; then
      notify-send -u low "Nothing to kill"
      exit 1
    fi

    PKILL_OUT=$(pkill -e "$DMENU_OUT")

    if [ $? -eq 0 ]; then
      notify-send -u normal "$PKILL_OUT"
      exit $?
    else
      notify-send -u critical "Kill $DMENU_OUT failed with code $?"
    fi
  '';
  i3Exit = ''
    USAGE="Usage: i3exit (hibernate|lock|reboot|shutdown)"
    case "$1" in
      "hibernate")
        systemctl hibernate
        ;;
      "lock")
        i3lock
        ;;
      "reboot")
        reboot
        ;;
      "suspend")
        systemctl suspend
        ;;
      "shutdown")
        shutdown now
        ;;
      *)
        echo $USAGE
        exit 1
        ;;
    esac
  '';

  # i3status configuration file content
  i3statusConfig = import ./i3status-config.nix { inherit theme; };

  notifyVolumeContent = ''
    VOLUME_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{ print $2 }')
    VOLUME=$(echo "$VOLUME_RAW * 100" | ${pkgs.bc}/bin/bc)

    if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "\[MUTED\]"; then
      notify-send "Volume" "Muted" --urgency low --hint "int:value:$VOLUME" --hint string:synchronous:my_volume
    else
      notify-send "Volume" "$VOLUME%" --urgency normal --hint "int:value:$VOLUME" --hint string:synchronous:my_volume
    fi
  '';

in
{
  options.desktop = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    primaryScreen = mkOption {
      type = types.str;
      default = "HDMI-0";
    };

    wallpaper = mkOption {
      type = types.path;
      description = "wallpaper path";
    };
  };

  imports = [
    ../dmenu.nix
    ../bluetooth.nix
    ../st
    ../zsh
  ];

  config = mkIf cfg.enable {
    my.bluetooth.enable = true;
    dmenu.enable = true;
    st.enable = true;
    st.fontFamily = theme.fontFamily;
    st.fontSize = 32;
    zsh.enable = true;

    environment.systemPackages = with pkgs; [
      obsidian
      feh
      dconf
      (writeShellScriptBin "auto-screen" autoScreen)
      (writeShellScriptBin "dp" dp)
      (writeShellScriptBin "edp" edp)
      (writeShellScriptBin "hdmi" hdmi)
      (writeShellScriptBin "i3exit" i3Exit)
      (writeShellScriptBin "i3kill" i3Kill)
      (writeShellScriptBin "wallpaper-reset" resetWallpaper)
      (writeShellScriptBin "notify-volume" notifyVolumeContent)
    ];

    hardware.graphics.enable = true;

    services.xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      displayManager.startx.enable = true;
      desktopManager.xterm.enable = false;
      autoRepeatDelay = 200;
      autoRepeatInterval = 30;

      xkb = {
        layout = "us,ru";
        options =
          if config.base.keyboard.swapCapsEscape
          then "grp:win_space_toggle,caps:swapescape"
          else "grp:win_space_toggle";
      };

      windowManager.i3 = {
        enable = true;
        package = pkgs.i3-gaps;
        extraPackages = with pkgs; [
          i3status
          i3lock
        ];
      };
    };

    services.displayManager.defaultSession = "none+i3";

    services.libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat";
        disableWhileTyping = true;
      };
      touchpad = {
        tapping = false;
        middleEmulation = false;
        disableWhileTyping = true;
      };
    };

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };

    services.udisks2.enable = true;
    services.udisks2.mountOnMedia = true;

    xdg.mime.enable = true;
    xdg.mime.defaultApplications = {
      "application/pdf" = "org.gnome.Evince.desktop";
      "video/x-matroska" = "vlc.desktop";
      "video/mp4" = "vlc.desktop";
      "video/webm" = "vlc.desktop";
      "video/ogg" = "vlc.desktop";
      "video/quicktime" = "vlc.desktop";
      "video/x-msvideo" = "vlc.desktop";
      "image/png" = "viewnior.desktop";
      "image/gif" = "viewnior.desktop";
      "image/heic" = "viewnior.desktop";
      "image/jpeg" = "viewnior.desktop";
      "image/svg+xml" = "viewnior.desktop";
      "image/webp" = "viewnior.desktop";
      "x-scheme-handler/magnet" = "userapp-transmission-gtk-ULULF1.desktop";
      "x-scheme-handler/postman" = "Postman.desktop";
    };
    xdg.mime.addedAssociations = {
      "video/x-matroska" = "handbrake.desktop";
      "video/mp4" = "handbrake.desktop";
      "video/webm" = "handbrake.desktop";
      "video/ogg" = "handbrake.desktop";
      "video/quicktime" = "handbrake.desktop";
      "video/x-msvideo" = "handbrake.desktop";
      "image/png" = "gimp.desktop";
      "image/gif" = "gimp.desktop";
      "image/heic" = "gimp.desktop";
      "image/jpeg" = "gimp.desktop";
      "image/svg+xml" = "gimp.desktop";
      "image/webp" = "gimp.desktop";
    };

    fonts.packages = [
      pkgs.nerd-fonts.inconsolata
    ];

    services.dbus.packages = [ pkgs.dconf ];
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;

    home-manager.users.${username} = {
      home.packages = with pkgs; [
        chromium
        evince
        firefox
        galculator
        gimp
        glances
        inkscape
        libheif
        libnotify
        networkmanagerapplet
        ntfs3g
        pasystray
        pavucontrol
        pcmanfm
        picom
        shutter
        simplescreenrecorder
        slack
        tdesktop
        transmission_4-gtk
        viewnior
        vlc
        xorg.xkill
        zoom-us
        roboto
        discord
        handbrake
        upscayl
        libreoffice
        blender
        arduino
        freecad
      ];

      programs.vifm = {
        enable = true;

        extraConfig = ''
          filetype *.pdf,*.jpg,*.jpeg,*.png,*.gif xdg-open %f &

          ${if config.base.keyboard.layout == "hallmack" then ''
          nnoremap H L
          nnoremap L H
          nnoremap j <nop>
          nnoremap k <nop>
          '' else ""}
        '';
      };

      home.file.".config/i3status/config".text = i3statusConfig;

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

      xdg.configFile."i3/config".text = import ./i3-config.nix {
        inherit config pkgs theme;
        primaryScreen = cfg.primaryScreen;
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

      home.pointerCursor = {
        x11.enable = true;
        name = "Numix-Cursor";
        package = pkgs.numix-cursor-theme;
      };

      services.dunst = {
        enable = true;

        settings = {
          global = {
            notification_limit = 5;
            font = "${theme.fontFamily} 12";
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
            highlight = theme.blue;
            timeout = 5;
          };

          urgency_normal = {
            frame_color = theme.blue;
            highlight = theme.blue;
            timeout = 15;
          };

          urgency_critical = {
            frame_color = theme.red;
            highlight = theme.red;
            timeout = 0;
          };
        };
      };
    };
  };
}
