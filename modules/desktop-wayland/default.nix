{ config, lib, pkgs, forAllUsers, inputs, theme, fontPackages, ... }:

with lib;

let
  cfg = config.my.desktop;

  waitForSni = pkgs.writeShellScript "wait-for-sni" ''
    until ${pkgs.dbus}/bin/dbus-send --session --print-reply \
        --dest=org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus.GetNameOwner \
        string:org.kde.StatusNotifierWatcher 2>/dev/null; do
      sleep 1
    done
  '';

  clipboardPersistCb = pkgs.writeShellScript "clipboard-persist-cb" ''
    content=$(cat)
    types=$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null)
    pid_file="''${XDG_RUNTIME_DIR:-/tmp}/clipboard-persist.pid"

    # If our own wl-copy is still alive, this event was triggered by us — skip to break feedback loop
    if [ -f "$pid_file" ]; then
      our_pid=$(cat "$pid_file" 2>/dev/null)
      if [ -n "$our_pid" ] && kill -0 "$our_pid" 2>/dev/null; then
        exit 0
      fi
      rm -f "$pid_file"
    fi

    # Let file managers own their clipboard fully — don't interfere
    if printf '%s\n' "$types" | grep -q 'x-special'; then
      exit 0
    fi

    # Only persist plain text
    if [ -n "$types" ] && ! printf '%s\n' "$types" | grep -q 'text/plain'; then
      exit 0
    fi

    [ -z "$content" ] && exit 0

    printf '%s' "$content" | ${pkgs.wl-clipboard}/bin/wl-copy --foreground &
    echo $! > "$pid_file"
  '';

  # Waybar's reserved strip: configured height 30, grown to 51 by padding.
  barHeight = 51;

  # Floats a window under the Waybar module that opens it. fromRight is that
  # module's centre, measured off the bar — Hyprland cannot read Waybar.
  underBarModule = { fromRight, width, height }: {
    float = "yes";
    pin = "yes";
    move = "(monitor_w-${toString (fromRight + width / 2)}) ${toString barHeight}";
    size = "${toString width} ${toString height}";
  };

  # wlogout bakes its icons in an off-palette lavender. The shapes live in the
  # alpha channel, so `-colorize` repaints them without touching the mask.
  wlogoutIcons = pkgs.runCommand "wlogout-icons-one-dark" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    mkdir -p $out
    for icon in ${pkgs.wlogout}/share/wlogout/icons/*.png; do
      magick "$icon" -fill "${theme.foreground.main}" -colorize 100 \
        "$out/$(basename "$icon")"
    done
  '';

  nxe = pkgs.writeShellScriptBin "nxe" ''
    exec ${pkgs.kitty}/bin/kitty -d /etc/nixos \
      -e ${pkgs.zsh}/bin/zsh -c 'vim home.nix; exec ${pkgs.zsh}/bin/zsh'
  '';

in {
  options.my.desktop = {
    enable = mkEnableOption "Wayland Hyprland desktop environment";

    primaryScreen = mkOption {
      type = types.str;
      default = "HDMI-0";
    };

    monitors = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Hyprland monitor config strings. Falls back to primaryScreen if empty.";
    };
  };

  imports = [
    ../bluetooth
    ../zsh
    ../waybar
  ];

  config = mkIf cfg.enable {
    my.bluetooth.enable = true;
    my.zsh.enable = true;
    my.waybar.enable = true;

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

    security.pam.services.hyprlock = {};

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session.command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --asterisks \
            --user-menu \
            --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions
        '';
      };
    };

    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    programs.waybar.enable = true;

    services.udisks2.enable = true;
    services.udisks2.mountOnMedia = true;
    services.gvfs.enable = true;

    xdg.mime.enable = true;
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
      "text/plain" = "nvim-gui.desktop";
    };

    fonts.fontDir.enable = true;
    fonts.packages = fontPackages ++ [
      pkgs.nerd-fonts.noto
      pkgs.nerd-fonts.blex-mono
      pkgs.inter
      pkgs.material-design-icons
    ];

    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    xdg.portal.config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
      "org.freedesktop.impl.portal.Screenshot" = "hyprland";
    };

    services.dbus.packages = [ pkgs.dconf ];
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;

    environment.systemPackages = with pkgs; [
      kitty.terminfo

      obsidian
      dconf
      ntfs3g

      (writeShellScriptBin "notify-volume" ''
        VOLUME_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{ print $2 }')
        VOLUME=$(echo "$VOLUME_RAW * 100" | ${pkgs.bc}/bin/bc)

        if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "\[MUTED\]"; then
          notify-send "Volume" "Muted" --urgency low --hint "int:value:$VOLUME" --hint string:synchronous:my_volume
        else
          notify-send "Volume" "$VOLUME%" --urgency normal --hint "int:value:$VOLUME" --hint string:synchronous:my_volume
        fi
      '')

      (writeShellScriptBin "notify-mic" ''
        IS_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "\[MUTED\]" && echo "true" || echo "false")

        if [ "$IS_MUTED" = "true" ]; then
          notify-send "Microphone" "Muted" --urgency low --hint string:synchronous:my_mic
        else
          notify-send "Microphone" "Unmuted 🎤" --urgency normal --hint string:synchronous:my_mic
        fi
      '')

      (writeShellScriptBin "notify-caps" ''
        get_caps_state() {
          CAPS_LED_PATH=$(find /sys/class/leds/ -name "*capslock" 2>/dev/null | head -n 1)
          if [ -f "$CAPS_LED_PATH/brightness" ]; then
            cat "$CAPS_LED_PATH/brightness"
          else
            echo 0
          fi
        }

        CURRENT_STATE=$(get_caps_state)

        if [ "$CURRENT_STATE" -eq 1 ]; then
          MESSAGE="Caps Lock is ON ⬆️"
          ICON="caps-lock-on"
        else
          MESSAGE="Caps Lock is OFF ⬇️"
          ICON="caps-lock-off"
        fi

        notify-send -i "$ICON" "Keyboard Status" "$MESSAGE" --urgency normal --hint string:synchronous:my_caps
      '')

      wl-clipboard
      cliphist
    ];

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
    hardware.nvidia.open = true; # Recommended for 40-series cards
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      prime = {
        sync.enable = true;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:51:0:0";
        offload.enable = false;
        offload.enableOffloadCmd = false;
      };
    };
    boot.blacklistedKernelModules = [ "nouveau" "ntfs3" ];

    hardware.graphics.enable = true;
    hardware.graphics.extraPackages = with pkgs; [ nvidia-vaapi-driver ];

    environment.sessionVariables = {
      GBM_BACKEND = "nvidia-drm";
      NIXOS_OZONE_WL = "1";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };

    home-manager.users = forAllUsers {
      home.packages = with pkgs; [
        wofi
        wlogout
        hyprlock
        hyprgraphics
        hyprpicker
        grim
        slurp
        wlsunset
        xdg-desktop-portal-hyprland

        swaybg
        waypaper

        vivaldi
        ungoogled-chromium
        firefox

        arduino
        blender
        discord
        freecad
        galculator
        glances
        grimblast
        libheif
        libnotify
        libreoffice
        engrampa
        p7zip
        unrar
        networkmanager-openvpn
        networkmanagerapplet
        obs-studio
        pavucontrol
        pcmanfm
        roboto
        stretchly
        telegram-desktop
        transmission_4-gtk
        viewnior
        vlc

        (writeShellScriptBin "cps" "2>/dev/null 1>/dev/null kitty -d $PWD & disown")
        nxe
      ];

      services.udiskie = {
        enable = true;
        automount = true;
        notify = true;
      };

      xdg.configFile."mimeapps.list".force = true;
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory"           = "pcmanfm.desktop";
          "application/pdf"           = "org.gnome.Evince.desktop";
          "video/x-matroska"          = "vlc.desktop";
          "video/mp4"                 = "vlc.desktop";
          "video/webm"                = "vlc.desktop";
          "video/ogg"                 = "vlc.desktop";
          "video/quicktime"           = "vlc.desktop";
          "video/x-msvideo"           = "vlc.desktop";
          "image/png"                 = "viewnior.desktop";
          "image/gif"                 = "viewnior.desktop";
          "image/heic"                = "viewnior.desktop";
          "image/jpeg"                = "viewnior.desktop";
          "image/svg+xml"             = "viewnior.desktop";
          "image/webp"                = "viewnior.desktop";
          "text/plain"                = "nvim-gui.desktop";
          "text/markdown"             = "nvim-gui.desktop";
          "application/x-shellscript" = "nvim-gui.desktop";
          "application/json"          = "nvim-gui.desktop";
          "application/xml"           = "nvim-gui.desktop";
          "application/zip"             = "engrampa.desktop";
          "application/x-zip-compressed" = "engrampa.desktop";
          "application/x-tar"           = "engrampa.desktop";
          "application/x-compressed-tar" = "engrampa.desktop";
          "application/x-bzip-compressed-tar" = "engrampa.desktop";
          "application/x-xz-compressed-tar" = "engrampa.desktop";
          "application/x-7z-compressed" = "engrampa.desktop";
          "application/x-rar"           = "engrampa.desktop";
          "application/x-rar-compressed" = "engrampa.desktop";
          "x-scheme-handler/magnet"   = "userapp-transmission-gtk-ULULF1.desktop";
          "x-scheme-handler/postman"  = "Postman.desktop";
          "x-scheme-handler/http"     = "vivaldi-stable.desktop";
          "x-scheme-handler/https"    = "vivaldi-stable.desktop";
          "x-scheme-handler/about"    = "vivaldi-stable.desktop";
          "x-scheme-handler/unknown"  = "vivaldi-stable.desktop";
          "text/html"                 = "vivaldi-stable.desktop";
        };
      };

      programs.kitty.enable = true; # required for the default Hyprland config
      programs.kitty.keybindings = {
        "ctrl+shift+enter" = "no_op";
        "ctrl+shift+]" = "no_op";
        "ctrl+shift+[" = "no_op";
        "ctrl+shift+`" = "no_op";
        "ctrl+shift+w" = "no_op";
      };

      xdg.desktopEntries.nvim-gui = {
        name = "Neovim GUI";
        comment = "Open file in Neovim within default terminal";
        type = "Application";
        terminal = false;
        icon = "nvim";
        categories = [ "Utility" "TextEditor" "Development" ];

        exec = "${pkgs.kitty}/bin/kitty nvim %f";

        mimeType = [
          "text/plain"
          "text/markdown"
          "application/x-shellscript"
          "application/json"
          "application/xml"
        ];
      };
      xdg.desktopEntries.nxe = {
        name = "nxe";
        genericName = "NixOS Configuration";
        comment = "Edit the NixOS configuration in vim";
        type = "Application";
        terminal = false;
        icon = "nvim";
        exec = "${nxe}/bin/nxe";
        categories = [ "Utility" "TextEditor" "Development" ];
        settings = {
          Keywords = "nix;nixos;config;flake;vim;";
          StartupNotify = "true";
        };
      };
      xdg.desktopEntries.pcmanfm = {
        name = "File Manager";
        genericName = "File Manager";
        exec = "pcmanfm -n %U";
        icon = "system-file-manager";
        mimeType = [ "inode/directory" ];
        categories = [ "System" "FileTools" "FileManager" "Utility" "Core" ];
        settings = {
          StartupNotify = "true";
        };
      };

      wayland.windowManager.hyprland = {
        enable = true;
        configType = "hyprlang";
        # Use the Hyprland and portal packages from the NixOS module
        package = null;
        portalPackage = null;

        settings = {
          "$mod" = "ALT";

          monitor =
            if cfg.monitors != []
            then cfg.monitors
            else [ "${cfg.primaryScreen}, preferred, 0x0, 1" ", preferred, auto, 1" ];

          env = [
            "XCURSOR_SIZE,24"
            "HYPRCURSOR_SIZE,24"
          ];

          exec-once = [
            "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
            "${pkgs.waypaper}/bin/waypaper --restore"
            "${waitForSni} && ${pkgs.networkmanagerapplet}/bin/nm-applet"
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
            "${pkgs.wl-clipboard}/bin/wl-paste --watch ${clipboardPersistCb}"
            "wl-paste --type text --watch cliphist store"
            "wl-paste --type image --watch cliphist store"
            "${waitForSni} && ${pkgs.stretchly}/bin/stretchly"
          ];

          general = {
            gaps_in = 5;
            gaps_out = 20;
            border_size = 2;
            "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
            "col.inactive_border" = "rgba(595959aa)";
            resize_on_border = false;
            allow_tearing = false;
            layout = "dwindle";
          };

          decoration = {
            rounding = 10;
            active_opacity = 1.0;
            inactive_opacity = 1.0;
            shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
              color = "rgba(1a1a1aee)";
            };
            blur = {
              enabled = true;
              size = 3;
              passes = 1;
              vibrancy = 0.1696;
            };
          };

          input = {
            repeat_delay = 300;
            repeat_rate = 30;
            kb_layout = "us,ru";
            kb_options =
              if config.base.keyboard.swapCapsEscape
              then "grp:win_space_toggle,caps:swapescape"
              else "grp:win_space_toggle";
            follow_mouse = 1;
            sensitivity = 0.4;
            accel_profile = "flat";
            touchpad = {
              natural_scroll = false;
            };
          };

          gestures = {
            workspace_swipe_distance = 500;
            workspace_swipe_create_new = true;
          };

          dwindle = {
            pseudotile = true;
            preserve_split = true;
          };

          master = {
            new_status = "master";
          };

          misc = {
            force_default_wallpaper = -1;
            disable_hyprland_logo = false;
            disable_splash_rendering = false;
          };

          animations = {
            enabled = true;
            bezier = "snappy, 0.2, 1, 0.2, 1";
            animation = [
              "windows, 1, 10, snappy, popin 80%"
              "fade, 1, 3, snappy"
              "workspaces, 1, 10, snappy, slide"
            ];
          };

          bind =
            let
              dirs =
                if config.base.keyboard.layout == "hallmack"
                then { l = "G"; d = "A"; u = "E"; r = "O"; }
                else { l = "H"; d = "J"; u = "K"; r = "L"; };
              splitKey = if config.base.keyboard.layout == "hallmack" then "L" else "E";
            in [
              "$mod, Return, exec, kitty"
              "$mod, Escape, killactive"
              "$mod, D, exec, wofi --show drun"
              "$mod, F, fullscreen"
              "$mod, SPACE, togglefloating"
              "$mod, P, pseudo"
              "$mod, ${splitKey}, layoutmsg, togglesplit"
              "$mod, M, exec, pavucontrol"
              "$mod, W, exec, pcmanfm"
              "$mod SHIFT, R, exec, pkill waybar; waybar"
              "$mod, R, submap, resize"
              "$mod, 0, exec, wlogout"
              "$mod SHIFT, 0, exec, hyprlock"

              # Focus
              "$mod, ${dirs.l}, movefocus, l"
              "$mod, ${dirs.d}, movefocus, d"
              "$mod, ${dirs.u}, movefocus, u"
              "$mod, ${dirs.r}, movefocus, r"
              "$mod, left, movefocus, l"
              "$mod, down, movefocus, d"
              "$mod, up, movefocus, u"
              "$mod, right, movefocus, r"

              # Move windows
              "$mod SHIFT, ${dirs.l}, movewindow, l"
              "$mod SHIFT, ${dirs.d}, movewindow, d"
              "$mod SHIFT, ${dirs.u}, movewindow, u"
              "$mod SHIFT, ${dirs.r}, movewindow, r"
              "$mod SHIFT, left, movewindow, l"
              "$mod SHIFT, down, movewindow, d"
              "$mod SHIFT, up, movewindow, u"
              "$mod SHIFT, right, movewindow, r"

              # Workspace back/forth
              "$mod, B, workspace, previous"
              "$mod SHIFT, B, movetoworkspace, previous"

              # Special workspace
              "$mod, S, togglespecialworkspace, magic"
              "$mod SHIFT, S, movetoworkspace, special:magic"
              "$mod SHIFT, minus, exec, hypr-move-to-active-workspace"

              # Screenshot
              ", Print, exec, DEFAULT_TARGET_DIR=$HOME/Screenshots grimblast save area"

              # Audio (with notify)
              "$mod, C, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0 && notify-volume"
              "$mod, V, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0 && notify-volume"
              "$mod SHIFT, C, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && notify-volume"
              "$mod SHIFT, V, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10% && notify-volume"
              "$mod, T, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && notify-volume"
              "$mod, N, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && notify-mic"

              # Apps
              "$mod, F2, exec, galculator"
              "$mod, F4, exec, transmission-gtk"
              "$mod, F6, exec, kitty glances"
            ]
            ++ map (n: "$mod, ${toString n}, workspace, ${toString n}") (lib.range 1 9)
            ++ map (n: "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}") (lib.range 1 9)
            ++ map (n: "$mod CTRL, ${toString n}, movetoworkspacesilent, ${toString n}") (lib.range 1 9);

          bindel = [
            ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            ", XF86MonBrightnessUp, exec, brightnessctl s 10%+"
            ", XF86MonBrightnessDown, exec, brightnessctl s 10%-"
          ];

          bindl = [
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioPause, exec, playerctl play-pause"
            ", XF86AudioPrev, exec, playerctl previous"
            ", XF86AudioNext, exec, playerctl next"
          ];

          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
            ", mouse:275, resizewindow"
            ", mouse:276, movewindow"
          ];

          windowrule = [
            { name = "firefox-workspace"; "match:class" = "^(firefox)$"; workspace = "1 silent"; }
            { name = "slack-workspace"; "match:class" = "^(slack)$"; workspace = "3 silent"; }
            { name = "pcmanfm-float"; "match:class" = "^(pcmanfm)$"; float = "yes"; }
            ({
              name = "nm-float-pin";
              "match:class" = "^(nm-connection-editor)$";
            } // underBarModule { fromRight = 907; width = 400; height = 400; })
            ({
              name = "pavucontrol-float-pin";
              "match:class" = "^(org\\.pulseaudio\\.pavucontrol)$";
            } // underBarModule { fromRight = 460; width = 800; height = 500; })
            { name = "suppress-maximize"; "match:class" = ".*"; suppress_event = "maximize"; }
            {
              name = "fix-xwayland-drags";
              "match:class" = "^$";
              "match:float" = true;
              "match:fullscreen" = false;
              "match:pin" = false;
              "match:title" = "^$";
              "match:xwayland" = true;
              no_focus = true;
            }
            {
              name = "wofi-float";
              "match:class" = "^(wofi)$";
              center = true;
              float = "yes";
              pin = "yes";
              size = "520 320";
              dim_around = true;
            }
            {
              name = "stretchly-break";
              "match:class" = "^electron$";
              "match:title" = "^Time to take a break!$";
              center = true;
              pin = "yes";
              dim_around = true;
            }
          ];
        };

        extraConfig = ''
          submap = resize
          binde = , G, resizeactive, -100 0
          binde = , A, resizeactive, 0 100
          binde = , E, resizeactive, 0 -100
          binde = , O, resizeactive, 100 0
          binde = , left, resizeactive, -100 0
          binde = , down, resizeactive, 0 100
          binde = , up, resizeactive, 0 -100
          binde = , right, resizeactive, 100 0
          bind = , Escape, submap, reset
          submap = reset
        '';
      };

      xdg.configFile."wofi/config".text = ''
        mode=drun
        allow-markup=true
        enable-advanced-run=true
        line-wrap=true
        image-size=28
        normal_window=true
        width=520
        height=320
        anchor=center
        hide-scroll=true
        prompt= Search...
        columns=1
        matching=fuzzy
        allow-empty-run=false
        output=auto
      '';

      xdg.configFile."wofi/style.css".text = ''
        window {
          font-family: "${theme.fontUI}", monospace;
          font-size: 17px;
          letter-spacing: 0.2px;
          margin: 0px;
          background-color: #44475a;
          border-radius: 10px;
        }

        #input {
          margin: 14px 8px;
          border: none;
          color: #f8f8f2;
        }

        #inner-box {
          margin: 0 8px 8px;
          border: none;
          background-color: #282a36;
        }

        #outer-box {
          border: none;
          background-color: #282a36;
        }

        #scroll {
          border: none;
          max-height: 300px;
        }

        #text {
          margin: 0px 6px;
          color: #f8f8f2;
          border: none;
        }

        #entry.activatable #text {
          color: #282a36;
        }

        #entry > * {
          color: #f8f8f2;
        }

        #entry:selected {
          background-color: #44475a;
        }
      '';

      # https://github.com/end-4/dots-hyprland/blob/main/dots/.config/kitty/kitty.conf
      # https://github.com/end-4/dots-hyprland/blob/main/dots/.config/wlogout/style.css
      xdg.configFile."wlogout/layout".text = lib.concatMapStrings (entry: builtins.toJSON entry + "\n") [
        { label = "lock";      action = "hyprlock";                        text = "Lock";      keybind = "l"; }
        { label = "hibernate"; action = "systemctl hibernate";             text = "Hibernate"; keybind = "h"; }
        { label = "logout";    action = "loginctl terminate-user $USER";   text = "Logout";    keybind = "e"; }
        { label = "shutdown";  action = "systemctl poweroff";              text = "Shutdown";  keybind = "s"; }
        { label = "suspend";   action = "systemctl suspend";               text = "Suspend";   keybind = "u"; }
        { label = "reboot";    action = "systemctl reboot";                text = "Reboot";    keybind = "r"; }
      ];

      xdg.configFile."wlogout/style.css".text = ''
        * {
          font-family: "${theme.fontMono}", monospace;
          background-image: none;
        }

        window {
          background-color: rgba(40, 44, 52, 0.92);
        }

        button {
          color: ${theme.foreground.main};
          background-color: ${theme.background.light};
          border: 1px solid ${theme.foreground.dark};
          border-radius: 10px;
          margin: 10px;
          background-repeat: no-repeat;
          background-position: center;
          background-size: 64px;
          font-size: 16px;
          /* Materia's ripple animates background-size to 1000% on :active, and
             a running animation outranks any static value. */
          animation: none;
          outline: none;
        }

        #logout    { background-image: url("${wlogoutIcons}/logout.png");    }
        #shutdown  { background-image: url("${wlogoutIcons}/shutdown.png");  }
        #reboot    { background-image: url("${wlogoutIcons}/reboot.png");    }
        #suspend   { background-image: url("${wlogoutIcons}/suspend.png");   }
        #hibernate { background-image: url("${wlogoutIcons}/hibernate.png"); }
        #lock      { background-image: url("${wlogoutIcons}/lock.png");      }

        /* No `:focus` rule: GTK focuses the first button, which would read as
           a preselected option. */
        button:hover {
          background-color: ${theme.foreground.dark};
          border-color: ${theme.blue};
          color: ${theme.blue};
        }

        button:active {
          background-color: ${theme.background.main};
          border-color: ${theme.blue};
          color: ${theme.blue};
        }
      '';

      programs.hyprlock = {
        enable = true;
        settings = {
          general = {
            hide_cursor = true;
          };
          background = [{
            monitor = "";
            path = "screenshot";
            blur_passes = 3;
            blur_size = 7;
            brightness = 0.5;
          }];
          input-field = [{
            monitor = "";
            size = "300, 50";
            outline_thickness = 2;
            dots_spacing = 0.3;
            outer_color = "rgba(33ccffee) rgba(00ff99ee) 45deg";
            inner_color = "rgba(0, 0, 0, 0.0)";
            font_color = "rgb(cdd6f4)";
            fade_on_empty = false;
            placeholder_text = "Password...";
            rounding = 15;
            position = "0, -60";
            halign = "center";
            valign = "center";
          }];
          label = [
            {
              monitor = "";
              text = "$TIME";
              color = "rgba(255, 255, 255, 0.9)";
              font_size = 72;
              font_family = theme.fontMono;
              position = "0, 200";
              halign = "center";
              valign = "center";
            }
            {
              monitor = "";
              text = ''cmd[update:60000] date +"%A, %d %B %Y"'';
              color = "rgba(255, 255, 255, 0.7)";
              font_size = 24;
              font_family = theme.fontMono;
              position = "0, 120";
              halign = "center";
              valign = "center";
            }
          ];
        };
      };

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

      dconf = {
        enable = true;
        settings."org.gnome.desktop.wm.preferences".button-layout = "appmenu:close";
        settings."org.gnome.desktop.interface".overlay-scrolling = false;
      };

      gtk = {
        enable = true;
        theme = {
          name = "Materia-dark-compact";
          package = pkgs.materia-theme;
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        font = {
          name = "Inter";
          size = 12;
        };
        gtk3.extraConfig = {
          "gtk-overlay-scrolling" = false;
        };
        gtk4 = {
          theme = null;
          extraConfig = {
            "gtk-overlay-scrolling" = false;
          };
        };
      };

      home.pointerCursor = {
        gtk.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 17;
      };

      # Day/night colour-temperature via wlsunset. hyprsunset (0.3.3) has no
      # transition support: it snaps to a profile's temperature at its `time`
      # and rejects `transition_duration` (that option does not exist upstream).
      # wlsunset instead ramps gradually over `-d` seconds in manual mode:
      #   morning: night -> day over (sunrise - d) .. sunrise
      #   evening: day -> night over sunset .. (sunset + d)
      # A single `-d` applies to both edges, so the 30 min / 2 h split is folded
      # into one 2 h transition: warm-up finishes at 07:00, dimming runs 18:30 ..
      # 20:30. The service binds to graphical-session.target, as hyprsunset did.
      systemd.user.services.wlsunset = {
        Unit = {
          Description = "Day/night colour temperature (wlsunset)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service.ExecStart =
          "${pkgs.wlsunset}/bin/wlsunset -S 07:00 -s 18:30 -T 6500 -t 3500 -d 7200";
        Install.WantedBy = [ "graphical-session.target" ];
      };

      services.dunst = {
        enable = true;

        settings = {
          global = {
            monitor = "keyboard";
            notification_limit = 5;
            font = "${theme.fontMono} 12";
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
