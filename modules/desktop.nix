{ config, lib, pkgs, username, theme, ... }:

with lib;

let
  cfg = config.desktop;
  resetWallpaper = "${pkgs.feh}/bin/feh --no-fehbg --bg-scale ${cfg.wallpaper}";

in
{
  imports = [
    ../pkgs/dmenu.nix
    ../pkgs/dmenu-history.nix
  ];

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
        libheif
        vlc
        xorg.xkill
        zoom-us
        networkmanagerapplet
        inkscape
        firefox
        glances
        ntfs3g
        gimp
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

      xdg.configFile."i3/config".text = ''
        # Autostart applications
        # exec --no-startup-id ${pkgs.dunst}/bin/dunst
        exec --no-startup-id ${pkgs.picom}/bin/picom -b
        exec --no-startup-id ${pkgs.pasystray}/bin/pasystray
        exec --no-startup-id ${pkgs.networkmanagerapplet}/bin/nm-applet
        exec --no-startup-id /home/egor/Projects/remarq/serve.sh

        for_window [title="File Transfer*"] floating enable
        for_window [class="Galculator"] floating enable sticky enable
        for_window [class="Pavucontrol"] floating enable
        for_window [class="Viewnior"] floating enable
        for_window [class="vlc*"] floating enable
        for_window [class="^Pcmanfm$"] floating enable resize set 1300 1100
        for_window [class="SimpleScreenRecorder"] floating enable sticky enable
        for_window [class="Transmission-gtk"] floating enable
        for_window [class="Evince"] floating enable
        for_window [class=".shutter-wrapped"] floating enable sticky enable

        set $mod Mod1

        default_border pixel 1
        default_floating_border pixel 1

        hide_edge_borders none

        font xft:${theme.fontFamily} 13

        floating_modifier $mod

        bindsym $mod+Return exec --no-startup-id i3-sensible-terminal

        bindsym $mod+Escape kill

        bindsym $mod+d exec "dmenu-history -p ' λ '"

        ${if config.hardware.pulseaudio.enable then ''
          bindsym XF86AudioMute exec "pactl -- set-sink-mute @DEFAULT_SINK@ toggle && notify-send -u low 'Volume mute toggle'"
          bindsym XF86AudioLowerVolume exec "pactl -- set-sink-volume @DEFAULT_SINK@ -5% && notify-send -u low 'Volume down'"
          bindsym XF86AudioRaiseVolume exec "pactl -- set-sink-volume @DEFAULT_SINK@ +5% && notify-send -u low 'Volume up'"
        '' else ""}

        bindsym $mod+F2 exec ${pkgs.galculator}/bin/galculator
        bindsym $mod+F3 exec ${pkgs.pcmanfm}/bin/pcmanfm
        bindsym $mod+F4 exec ${pkgs.transmission-gtk}/bin/transmission-gtk
        bindsym $mod+F5 exec ${pkgs.simplescreenrecorder}/bin/simplescreenrecorder
        bindsym $mod+F6 exec ${pkgs.glances}/bin/glances
        bindsym Print exec --no-startup-id ${pkgs.shutter}/bin/shutter
        bindsym $mod+Ctrl+x --release exec --no-startup-id ${pkgs.xorg.xkill}/bin/xkill
        bindsym $mod+Ctrl+m exec ${pkgs.pavucontrol}/bin/pavucontrol

        ${if config.desktop.hallmack then ''
          bindsym $mod+g focus left
          bindsym $mod+a focus down
          bindsym $mod+e focus up
          bindsym $mod+o focus right

          bindsym $mod+Shift+g move left
          bindsym $mod+Shift+a move down
          bindsym $mod+Shift+e move up
          bindsym $mod+Shift+o move right
        '' else ''
          bindsym $mod+h focus left
          bindsym $mod+j focus down
          bindsym $mod+k focus up
          bindsym $mod+l focus right

          bindsym $mod+Shift+h move left
          bindsym $mod+Shift+j move down
          bindsym $mod+Shift+k move up
          bindsym $mod+Shift+l move right
        ''}

        bindsym $mod+Left focus left
        bindsym $mod+Down focus down
        bindsym $mod+Up focus up
        bindsym $mod+Right focus right

        bindsym $mod+Shift+Left move left
        bindsym $mod+Shift+Down move down
        bindsym $mod+Shift+Up move up
        bindsym $mod+Shift+Right move right

        # workspace back and forth (with/without active container)
        workspace_auto_back_and_forth yes
        bindsym $mod+b workspace back_and_forth
        bindsym $mod+Shift+b move container to workspace back_and_forth; workspace back_and_forth

        ${if config.desktop.hallmack then ''
          bindsym $mod+h split h;exec notify-send -u low 'tile horizontally'
        '' else ''
          bindsym $mod+z split h;exec notify-send -u low 'tile horizontally'
        ''}
        bindsym $mod+v split v;exec notify-send -u low 'tile vertically'
        bindsym $mod+q split toggle

        bindsym $mod+f fullscreen toggle

        # change container layout (stacked, tabbed, toggle split)
        bindsym $mod+s layout stacking
        bindsym $mod+w layout tabbed
        ${if config.desktop.hallmack then ''
          bindsym $mod+l layout toggle split
        '' else ''
          bindsym $mod+e layout toggle split
        ''}

        bindsym $mod+Shift+space floating toggle

        bindsym $mod+space focus mode_toggle

        # toggle sticky
        bindsym $mod+Shift+s sticky toggle

        # focus the parent container
        ${if config.desktop.hallmack then ''
          bindsym $mod+p focus parent
        '' else ''
          bindsym $mod+a focus parent
        ''}

        # move the currently focused window to the scratchpad
        bindsym $mod+Shift+minus move scratchpad

        # cycle through scratchpad windows
        bindsym $mod+minus scratchpad show

        # workspace names
        set $ws1 1
        set $ws2 2
        set $ws3 3
        set $ws4 4
        set $ws5 5
        set $ws6 6
        set $ws7 7
        set $ws8 8
        set $ws9 9

        # switch to workspace
        bindsym $mod+1 workspace $ws1
        bindsym $mod+2 workspace $ws2
        bindsym $mod+3 workspace $ws3
        bindsym $mod+4 workspace $ws4
        bindsym $mod+5 workspace $ws5
        bindsym $mod+6 workspace $ws6
        bindsym $mod+7 workspace $ws7
        bindsym $mod+8 workspace $ws8
        bindsym $mod+9 workspace $ws9

        # Move focused container to workspace
        bindsym $mod+Ctrl+1 move container to workspace $ws1
        bindsym $mod+Ctrl+2 move container to workspace $ws2
        bindsym $mod+Ctrl+3 move container to workspace $ws3
        bindsym $mod+Ctrl+4 move container to workspace $ws4
        bindsym $mod+Ctrl+5 move container to workspace $ws5
        bindsym $mod+Ctrl+6 move container to workspace $ws6
        bindsym $mod+Ctrl+7 move container to workspace $ws7
        bindsym $mod+Ctrl+8 move container to workspace $ws8
        bindsym $mod+Ctrl+9 move container to workspace $ws9

        # Move to workspace with focused container
        bindsym $mod+Shift+1 move container to workspace $ws1; workspace $ws1
        bindsym $mod+Shift+2 move container to workspace $ws2; workspace $ws2
        bindsym $mod+Shift+3 move container to workspace $ws3; workspace $ws3
        bindsym $mod+Shift+4 move container to workspace $ws4; workspace $ws4
        bindsym $mod+Shift+5 move container to workspace $ws5; workspace $ws5
        bindsym $mod+Shift+6 move container to workspace $ws6; workspace $ws6
        bindsym $mod+Shift+7 move container to workspace $ws7; workspace $ws7
        bindsym $mod+Shift+8 move container to workspace $ws8; workspace $ws8
        bindsym $mod+Shift+9 move container to workspace $ws9; workspace $ws9

        assign [class="Slack"] $ws3

        # reload the configuration file
        bindsym $mod+Shift+c reload

        # restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
        bindsym $mod+Shift+r restart

        # exit i3 (logs you out of your X session)
        ${if config.desktop.hallmack then ''
          bindsym $mod+Shift+q exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"
        '' else ''
          bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"
        ''}

        # Set shut down, restart and locking features TODO fix, doesn't work
        bindsym $mod+0 mode "$mode_system"
        set $mode_system (l)ock, (e)xit, switch_(u)ser, (s)uspend, (h)ibernate, (r)eboot, (Shift+s)hutdown
        mode "$mode_system" {
          bindsym l exec --no-startup-id i3exit lock, mode "default"
          bindsym s exec --no-startup-id i3exit suspend, mode "default"
          bindsym u exec --no-startup-id i3exit switch_user, mode "default"
          bindsym e exec --no-startup-id i3exit logout, mode "default"
          bindsym h exec --no-startup-id i3exit hibernate, mode "default"
          bindsym r exec --no-startup-id i3exit reboot, mode "default"
          bindsym Shift+s exec --no-startup-id i3exit shutdown, mode "default"

          bindsym Return mode "default"
          bindsym Escape mode "default"
        }

        # Resize window (you can also use the mouse for that)
        bindsym $mod+r mode "resize"
        mode "resize" {
          ${if config.desktop.hallmack then ''
            bindsym g resize shrink width 5 px or 5 ppt
            bindsym a resize grow height 5 px or 5 ppt
            bindsym e resize shrink height 5 px or 5 ppt
            bindsym o resize grow width 5 px or 5 ppt
          '' else ''
            bindsym h resize shrink width 5 px or 5 ppt
            bindsym j resize grow height 5 px or 5 ppt
            bindsym k resize shrink height 5 px or 5 ppt
            bindsym l resize grow width 5 px or 5 ppt
          ''}

          bindsym Left resize shrink width 10 px or 10 ppt
          bindsym Down resize grow height 10 px or 10 ppt
          bindsym Up resize shrink height 10 px or 10 ppt
          bindsym Right resize grow width 10 px or 10 ppt

          bindsym Return mode "default"
          bindsym Escape mode "default"
        }

        # Start i3bar to display a workspace bar (plus the system information i3status if available)
        bar {
          i3bar_command i3bar
          status_command i3status
          position bottom

          bindsym button4 nop
          bindsym button5 nop
          strip_workspace_numbers yes
          tray_padding 3

          colors {
            background ${theme.background.light}
            statusline ${theme.foreground.main}
            separator  ${theme.foreground.dark}

            focused_workspace  ${theme.blue}            ${theme.background.main} ${theme.foreground.main}
            active_workspace   ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.main}
            inactive_workspace ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.main}
            urgent_workspace   ${theme.red}             ${theme.background.main} ${theme.foreground.main}
            binding_mode       ${theme.red}             ${theme.background.main} ${theme.foreground.main}
          }
        }

        # hide/unhide i3status bar
        bindsym $mod+m bar mode toggle

        #                       border                   background               foreground               indicator                child_border
        client.focused          ${theme.blue}            ${theme.background.main} ${theme.foreground.main} ${theme.green}           ${theme.blue}
        client.focused_inactive ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.main} ${theme.foreground.dark} ${theme.foreground.dark}
        client.unfocused        ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.dark} ${theme.foreground.dark} ${theme.foreground.dark}
        client.urgent           ${theme.red}             ${theme.background.main} ${theme.red}             ${theme.green}           ${theme.red}
        client.placeholder      ${theme.background.main} ${theme.background.main} ${theme.foreground.dark} ${theme.foreground.dark} ${theme.background.main}

        client.background       ${theme.background.main}

        # Set inner/outer gaps
        gaps inner 12
        gaps outer 0

        # Smart gaps (gaps used if only more than one container on the workspace)
        smart_gaps on

        # Smart borders (draw borders around container only if it is not the only container on this workspace)
        smart_borders on
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
            image = mkAssociation "viewnior.desktop" [ "image/gif" "image/jpeg" "image/png" "image/webp" "image/heic" ];
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
