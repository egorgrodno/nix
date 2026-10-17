{
  config,
  lib,
  pkgs,
  forAllUsers,
  theme,
  fontPackages,
  ...
}:

with lib;

let
  cfg = config.my.desktop;

  rgba = import ../../lib/rgba.nix lib;
  hyprColor = import ../../lib/hypr-color.nix lib;

  # The focused-window accent, reused by hyprlock's password field so the lock
  # screen and the session agree on what "active" looks like.
  activeBorder = "${hyprColor theme.blue "ff"} ${hyprColor theme.cyan "ff"} 45deg";

  # Hyprland's directional keys: focus, move, and the resize submap.
  dirs =
    if config.base.keyboard.layout == "hallmack" then
      {
        l = "G";
        d = "A";
        u = "E";
        r = "O";
      }
    else
      {
        l = "H";
        d = "J";
        u = "K";
        r = "L";
      };

  # tuigreet writes ANSI to a pty, which a bare Wayland compositor cannot hand
  # it, so the greeter runs inside foot.
  greeterTerminal =
    let
      hex = removePrefix "#";
    in
    pkgs.writeText "foot-greeter.ini" ''
      font=${theme.fontMono}:size=14
      # Without this a desktop appearance preference can select the empty
      # `colors-light` section.
      initial-color-theme=dark
      # Without this foot maps at its 700x500 default and is only then resized
      # by cage, which reads on screen as the greeter snapping to size.
      initial-window-mode=fullscreen

      [colors-dark]
      background=${hex theme.background.main}
      foreground=${hex theme.foreground.main}

      regular0=${hex theme.background.light}
      regular1=${hex theme.red}
      regular2=${hex theme.green}
      regular3=${hex theme.yellow}
      regular4=${hex theme.blue}
      regular5=${hex theme.magenta}
      regular6=${hex theme.cyan}
      regular7=${hex theme.foreground.muted}

      bright0=${hex theme.foreground.dark}
      bright1=${hex theme.bright.red}
      bright2=${hex theme.bright.green}
      bright3=${hex theme.bright.yellow}
      bright4=${hex theme.bright.blue}
      bright5=${hex theme.bright.magenta}
      bright6=${hex theme.bright.cyan}
      bright7=${hex theme.foreground.light}
    '';

  # tuigreet names ANSI roles, not colours, so these resolve against the palette
  # above: `black` is its regular0, `gray` regular7, `white` bright7. Restyling
  # means naming a different role, never a hex value. `title` follows `border`
  # and `greet` follows `text`, which is why neither is listed.
  greeterTheme = "container=black;border=blue;text=gray;time=cyan;prompt=cyan;input=white;action=gray;button=yellow";

  waitForSni = pkgs.writeShellScript "wait-for-sni" ''
    until ${pkgs.dbus}/bin/dbus-send --session --print-reply \
        --dest=org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus.GetNameOwner \
        string:org.kde.StatusNotifierWatcher 2>/dev/null; do
      sleep 1
    done
  '';

  clipboardPersistCb = pkgs.writeShellScript "clipboard-persist-cb" ''
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

    # The payload arrives on stdin, but `$(cat)` would strip every trailing
    # newline and `printf '%s'` cannot put them back — a line-wise yank would
    # come back without the `\n` that makes a shell paste auto-execute. Re-read
    # the selection instead, so the bytes never pass through the shell.
    [ "$(${pkgs.wl-clipboard}/bin/wl-paste --no-newline | wc -c)" -eq 0 ] && exit 0

    ${pkgs.wl-clipboard}/bin/wl-paste --no-newline \
      | ${pkgs.wl-clipboard}/bin/wl-copy --foreground &
    echo $! > "$pid_file"
  '';

  # The bar's strip, which Quickshell is built to and reserves as its exclusive
  # zone.
  barHeight = 51;

  # Centre of each module a window docks under, in px from the screen's right
  # edge, measured off the bar: Hyprland cannot read its layout.
  barModuleCentre = {
    network = 940;
    volume = 370;
  };

  # Floats a window under the bar module that opens it, centred on the module
  # unless that would take it past the 20 px outer gap on the right.
  underBarModule =
    {
      fromRight,
      width,
      height,
    }:
    {
      float = "yes";
      pin = "yes";
      move = "(monitor_w-${
        toString (lib.max (fromRight + width / 2) (width + 20))
      }) ${toString barHeight}";
      size = "${toString width} ${toString height}";
    };

  # Windows tile; a class earns a float rule by being dismissed rather than
  # inhabited, and the kind it lands in fixes the geometry once. Matching is
  # case-insensitive: the same program reports a capitalised WM_CLASS under
  # XWayland and a lowercase app id when built native. RE2 honours `(?i)`.
  floatRule =
    kind: props: class:
    {
      name = "${kind}-${class}";
      "match:class" = "(?i)^(${escapeRegex class})$";
      float = "yes";
      center = true;
    }
    // props;

  # A fraction of the display, not pixels: one module serves fractal's 2560x1440
  # and the thinkpad's panel, so a constant is right on at most one of them.
  # `size` is evaluated by muParser over `monitor_w`/`monitor_h`, so a term
  # carries no spaces and a percentage would throw at map time.
  manager = floatRule "manager" { size = "monitor_w*0.47 monitor_h*0.62"; };
  utility = floatRule "utility" { size = "monitor_w*0.23 monitor_h*0.35"; };

  # The content sets the shape, so none is imposed. `max_size` would clamp it,
  # but it takes pixels only and any ceiling would be wrong on one of the hosts.
  viewer = floatRule "viewer" { };
  dialog = floatRule "dialog" { };

  # wlogout bakes its icons in an off-palette lavender. The shapes live in the
  # alpha channel, so `-colorize` repaints them without touching the mask.
  wlogoutIcons =
    pkgs.runCommand "wlogout-icons-one-dark"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        for icon in ${pkgs.wlogout}/share/wlogout/icons/*.png; do
          magick "$icon" -fill "${theme.foreground.main}" -colorize 100 \
            "$out/$(basename "$icon")"
        done
      '';

  # The idle dim. A screen shader rather than brightnessctl, since an external
  # monitor has no backlight to turn down.
  dimShader = pkgs.writeText "dim.frag" ''
    #version 300 es
    precision mediump float;

    in vec2 v_texcoord;
    uniform sampler2D tex;
    out vec4 fragColor;

    void main() {
      vec4 color = texture(tex, v_texcoord);
      fragColor = vec4(color.rgb * 0.4, color.a);
    }
  '';

  # Minutes of idle before each step, per power profile. Hibernation follows
  # the suspend after HibernateDelaySec.
  idleMinutes = {
    performance = {
      dim = 10;
      lock = 15;
      suspend = 20;
    };
    balanced = {
      dim = 3;
      lock = 5;
      suspend = 5;
    };
    power-saver = {
      dim = 1;
      lock = 2;
      suspend = 2;
    };
  };

  # In seconds. A suspend in the lock's minute trails it by 5 s, so hyprlock
  # is up before the outputs go dark.
  idleTimeouts = mapAttrs (_: m: {
    dim = m.dim * 60;
    lock = m.lock * 60;
    suspend = m.suspend * 60 + (if m.suspend == m.lock then 5 else 0);
  }) idleMinutes;

  # hypridle owns org.freedesktop.ScreenSaver, so restarting it on a profile
  # change would drop every app's idle inhibit. It runs every profile's
  # listeners instead, and each runs its step once the step is due under the
  # active profile: the first field of last_pwr, missing on a host without TLP.
  # A step that a profile change moved into the past runs at the next listener
  # for it.
  idleStep =
    let
      due = t: "dim=${toString t.dim} lock=${toString t.lock} suspend=${toString t.suspend}";
    in
    pkgs.writeShellScript "idle-step" ''
      read -r pwr _ 2>/dev/null </run/tlp/last_pwr
      case $pwr in
        1) ${due idleTimeouts.balanced} ;;
        2) ${due idleTimeouts.power-saver} ;;
        *) ${due idleTimeouts.performance} ;;
      esac

      case $1 in
        dim) [ "$2" -ge "$dim" ] && hyprctl keyword decoration:screen_shader ${dimShader} ;;
        lock) [ "$2" -ge "$lock" ] && loginctl lock-session ;;
        suspend) [ "$2" -ge "$suspend" ] && systemctl suspend-then-hibernate ;;
      esac
    '';

  # vim must start from an interactive shell: `:suspend` signals its whole
  # process group, and `zsh -c` has no job control to put vim in one of its
  # own, so ^Z stops the shell too and freezes the window. The throwaway
  # ZDOTDIR sources the real one, so that shell is still the configured one.
  nxe = pkgs.writeShellScriptBin "nxe" ''
    set -eu
    zdotdir=$(mktemp -d)

    # ZDOTDIR is unset when nxe is launched from the desktop entry, so resolve
    # it the way zsh does rather than reading it from this environment.
    cat >"$zdotdir/.zshenv" <<'EOF'
    nxe_tmp=$ZDOTDIR
    [ -r "$HOME/.zshenv" ] && . "$HOME/.zshenv"
    [ "$ZDOTDIR" = "$nxe_tmp" ] && ZDOTDIR=$HOME
    nxe_real=$ZDOTDIR
    ZDOTDIR=$nxe_tmp
    EOF

    cat >"$zdotdir/.zshrc" <<'EOF'
    ZDOTDIR=$nxe_real
    [ -r "$ZDOTDIR/.zshrc" ] && . "$ZDOTDIR/.zshrc"
    rm -rf "$nxe_tmp"
    unset nxe_tmp nxe_real
    vim home.nix
    EOF

    export ZDOTDIR="$zdotdir"
    exec ${pkgs.kitty}/bin/kitty -d /etc/nixos -e ${pkgs.zsh}/bin/zsh
  '';

in
{
  options.my.desktop = {
    enable = mkEnableOption "Wayland Hyprland desktop environment";

    primaryScreen = mkOption {
      type = types.str;
      default = "eDP-1";
      description = "Wayland connector name of the screen that carries the bar and tray.";
    };

    primaryMode = mkOption {
      type = types.str;
      default = "preferred";
      example = "2560x1440@120";
      description = ''
        Mode for the primary screen, as Hyprland's `<width>x<height>@<rate>`.
        The keywords `preferred`, `highres` and `highrr` are also accepted.
        Pinning a rate here is worthwhile whenever the EDID preferred mode is
        not the one wanted, since `preferred` follows the display rather than
        the configuration.
      '';
    };

    extraMonitors = mkOption {
      type = types.listOf types.str;
      default = [ ", preferred, auto, 1" ];
      example = [ "DP-1, 1920x1080@60, 2560x0, 1" ];
      description = ''
        Hyprland monitor strings for the outputs other than the primary, emitted
        after it. The primary is always generated from `primaryScreen` and
        `primaryMode`, so populating this list cannot silently drop it.
        The default catch-all gives any further display its preferred mode,
        placed to the right; replace it to position additional screens exactly.
      '';
    };
  };

  imports = [
    ../bluetooth
    ../zsh
    ../quickshell
  ];

  config = mkIf cfg.enable {
    my.bluetooth.enable = true;
    my.zsh.enable = true;
    my.quickshell = {
      enable = true;
      inherit barHeight;
    };

    # Enabled for the libinput udev rules only. The `mouse` and `touchpad`
    # option trees are gated on `services.xserver.enable` in nixpkgs, so they
    # are inert on Wayland; pointer behaviour lives in Hyprland's `input` block.
    services.libinput.enable = true;

    security.pam.services.hyprlock = { };

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };

    # cage rather than the kernel console: fbcon locks its character grid in at
    # boot and never re-probes, so a monitor swapped between power-on and login
    # leaves the greeter sized for the display that is gone. A host driving its
    # outputs from a discrete card must pin `WLR_DRM_DEVICES` in
    # `environment.sessionVariables` for the greeter to reach that card too.
    #
    # `withUWSM` publishes both a plain and a uwsm-managed Hyprland session and
    # the plain one sorts first; picking it leaves the compositor a child of
    # greetd, logging to the VT instead of the journal, with no systemd user
    # units. `--remember-session` makes one deliberate choice stick.
    services.greetd = {
      enable = true;
      settings = {
        default_session.command = ''
          ${pkgs.cage}/bin/cage -d -s -- \
            ${pkgs.foot}/bin/foot \
              --config=${greeterTerminal} \
              --term=xterm-256color \
              -e ${pkgs.tuigreet}/bin/tuigreet \
                --time \
                --asterisks \
                --user-menu \
                --remember-session \
                --theme '${greeterTheme}' \
                --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions
        '';
      };
    };

    # Kernel chatter makes the plain TTYs behind the greeter unreadable. This
    # must go through consoleLogLevel rather than kernelParams: NixOS appends
    # its own `loglevel=` from that option, and the kernel honours the last one.
    boot.consoleLogLevel = 3;

    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    services.udisks2.enable = true;
    services.udisks2.mountOnMedia = true;
    services.gvfs.enable = true;

    xdg.mime.enable = true;
    # Secondary handlers only — these widen the "Open with" list. The default
    # for every type below stays whatever `defaultApplications` names, so
    # images still open in viewnior rather than gimp.
    xdg.mime.addedAssociations = {
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
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
      "org.freedesktop.impl.portal.Screenshot" = "hyprland";
    };

    services.dbus.packages = [ pkgs.dconf ];
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;

    environment.variables.TERMINAL = "kitty";

    environment.systemPackages = with pkgs; [
      kitty.terminfo

      obsidian
      dconf
      ntfs3g
      brightnessctl # backs the XF86MonBrightness binds
      playerctl # backs the XF86Audio{Play,Pause,Prev,Next} binds

      (writeShellScriptBin "notify-volume" ''
        # printf "%d" truncates to an integer; bc would derive its scale from
        # the operands and yield 25.00, which is not a valid `int` hint.
        VOLUME=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{ printf "%d", $2 * 100 }')

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

      # `togglefloating` floats a window at whatever geometry its tile happened
      # to have, which is the geometry being escaped. This lands it where the
      # manager kind would have, for the windows no rule caught. Percentages
      # here go through the dispatcher rather than muParser, so they parse.
      (writeShellScriptBin "hypr-float-here" ''
        hyprctl --batch "dispatch setfloating ; dispatch resizeactive exact 47% 62% ; dispatch centerwindow"
      '')

      # Classifying a program means knowing the class it actually reports, which
      # is not derivable from its name: viewnior answers `Viewnior` under
      # XWayland, okular `org.kde.okular`, and blueman leaks its Nix wrapper.
      (writeShellScriptBin "hypr-window-class" ''
        hyprctl activewindow -j \
          | ${pkgs.jq}/bin/jq -r '"class: \(.class)\ninitialClass: \(.initialClass)\nxwayland: \(.xwayland)"' \
          | xargs -0 notify-send "Window class" --urgency normal --hint string:synchronous:my_class
      '')

      # The Hyprland equivalent of i3's `scratchpad show`: pull the first window
      # parked on the special workspace onto the focused one, so repeated
      # presses walk through the rest. `togglespecialworkspace` only overlays
      # that workspace, which is the other half of the workflow.
      (writeShellScriptBin "hypr-move-to-active-workspace" ''
        # With the overlay open the focused window is the one being looked at,
        # so it wins. Only when focus is elsewhere does the first parked window
        # apply, which lets repeated presses walk through the rest.
        ADDRESS=$(hyprctl activewindow -j \
          | ${pkgs.jq}/bin/jq -r 'select(.workspace.name == "special:magic") | .address // empty')

        if [ -z "$ADDRESS" ]; then
          ADDRESS=$(hyprctl clients -j \
            | ${pkgs.jq}/bin/jq -r 'map(select(.workspace.name == "special:magic")) | .[0].address // empty')
        fi

        if [ -z "$ADDRESS" ]; then
          notify-send "Scratchpad" "Empty" --urgency low --hint string:synchronous:my_scratchpad
          exit 0
        fi

        # `activeworkspace` keeps reporting the real workspace while the
        # special one is overlaid, so it is always a valid destination.
        WORKSPACE=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.id')

        hyprctl dispatch movetoworkspace "$WORKSPACE,address:$ADDRESS"
      '')

      # Scale is runtime state, the way the wallpaper is: the `monitor` setting
      # is what a session starts at, and `hyprctl keyword` overrides it until
      # the next config reload.
      (writeShellScriptBin "hypr-monitor-scale" ''
        read -r NAME W H RR X Y CURRENT < <(hyprctl monitors -j \
          | ${pkgs.jq}/bin/jq -r '.[] | select(.focused)
              | "\(.name) \(.width) \(.height) \(.refreshRate) \(.x) \(.y) \(.scale)"')

        if [ -z "$NAME" ]; then
          notify-send "Monitor scale" "No focused monitor" --urgency critical
          exit 1
        fi

        # Hyprland quantises a scale to 1/120 and substitutes one of its own for
        # any value that leaves the mode a fractional number of logical pixels,
        # so d/120 applies as written exactly when d divides 120*gcd(W, H).
        #
        # The two-decimal label is for reading; the exact scale rides in a
        # second tabbed field, since 1.875 is a divisor and 1.88 is not.
        MENU=$(${pkgs.gawk}/bin/awk -v w="$W" -v h="$H" -v cur="$CURRENT" 'BEGIN {
          a = w; b = h; while (b) { t = b; b = a % b; a = t }
          limit = 120 * a

          for (d = 120; d <= 240; d++) {
            if (limit % d) continue
            scale = d / 120
            mark = sprintf("%.2f", scale) == sprintf("%.2f", cur) ? "  (current)" : ""
            row = sprintf("%.2f  %-9s%s", scale, sprintf("%dx%d", w * 120 / d, h * 120 / d), mark)
            sub(/ +$/, "", row)
            printf "%s\t%.6f\n", row, scale
          }
        }')

        CHOICE=$(printf '%s\n' "$MENU" | cut -f1 | wofi --dmenu \
          --prompt "Scale $NAME" --width 320 --lines "$(printf '%s\n' "$MENU" | wc -l)")
        [ -n "$CHOICE" ] || exit 0

        SCALE=$(printf '%s\n' "$MENU" \
          | ${pkgs.gawk}/bin/awk -F'\t' -v c="$CHOICE" '$1 == c { print $2; exit }')
        LOGICAL=$(printf '%s\n' "$CHOICE" | ${pkgs.gawk}/bin/awk '{ print $2 }')

        # Mode and position are read back from the monitor rather than passed as
        # `auto`, which would re-run mode selection and re-lay-out every output.
        hyprctl keyword monitor "$NAME,''${W}x''${H}@''${RR},''${X}x''${Y},$SCALE"

        notify-send "Monitor scale" "$NAME at ''${CHOICE%% *}x — $LOGICAL" \
          --urgency normal --hint string:synchronous:my_scale
      '')

      # Saves an area capture and copies its path. With `--edit`, Satty opens
      # it first and saves over it, so the path is valid however Satty is
      # left, edited or not. The path then takes the clipboard unless Satty's
      # own copy already put the image there.
      (writeShellScriptBin "screenshot" ''
        FILE="$HOME/Screenshots/$(date +%Y%m%d_%H%M%S).png"
        COPIED="$XDG_RUNTIME_DIR/screenshot-$$"

        # A cancelled selection exits non-zero and writes no file.
        grimblast --freeze save area "$FILE" || exit 0

        if [ "$1" = --edit ]; then
          satty --filename "$FILE" --output-filename "$FILE" \
            --copy-command "wl-copy && touch '$COPIED'"

          if [ -e "$COPIED" ]; then
            rm "$COPIED"
            exit 0
          fi
        fi

        printf '%s' "$FILE" | wl-copy
        notify-send "Screenshot path copied" "$FILE" --urgency low --hint string:synchronous:my_screenshot
      '')

      wl-clipboard
      cliphist
    ];

    # Vendor-neutral: the driver, its VA-API backend and any vendor session
    # variables belong to the host.
    hardware.graphics.enable = true;

    # Paired with the ntfs3g package below; the in-kernel ntfs3 driver loses to it.
    boot.blacklistedKernelModules = [ "ntfs3" ];

    # hypridle's idle suspend hibernates after this delay, which logind refuses
    # on a host without swap, leaving the machine awake.
    assertions = [
      {
        assertion = config.swapDevices != [ ];
        message = "The desktop module suspends then hibernates on idle: declare swap at least the size of RAM in `swapDevices`.";
      }
    ];
    systemd.sleep.settings.Sleep.HibernateDelaySec = "10min";

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # Qt6 picks Wayland up on its own; Qt5 defaults to xcb and silently lands on
    # XWayland unless told otherwise. `xcb` stays as the fallback for any app
    # whose closure lacks the qtwayland plugin.
    environment.sessionVariables.QT_QPA_PLATFORM = "wayland;xcb";

    # uwsm narrates unit generation to stdout, which greetd points at the VT, so
    # every login paints the console before the compositor takes over. `1` keeps
    # warnings and errors, `2` would drop those too, and uwsm logs to syslog
    # either way.
    environment.sessionVariables.UWSM_SILENT_START = "1";

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
        gimp
        glances
        grimblast
        kdePackages.okular
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
        pwvucontrol
        pcmanfm
        roboto
        stretchly
        telegram-desktop
        transmission_4-gtk
        # nixpkgs pins GDK_BACKEND=x11, which forces XWayland; the later `--set`
        # overrides that `--set-default`. The pin guards an upstream bug where
        # panning a zoomed-in image does not work under Wayland.
        (viewnior.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            gappsWrapperArgs+=(--set GDK_BACKEND wayland,x11)
          '';
        }))
        showtime

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
          "inode/directory" = "pcmanfm.desktop";
          # Okular splits its associations per format; the main
          # org.kde.okular.desktop entry declares only okular-archive.
          "application/pdf" = "okularApplication_pdf.desktop";
          "video/x-matroska" = "org.gnome.Showtime.desktop";
          "video/mp4" = "org.gnome.Showtime.desktop";
          "video/webm" = "org.gnome.Showtime.desktop";
          "video/ogg" = "org.gnome.Showtime.desktop";
          "video/quicktime" = "org.gnome.Showtime.desktop";
          "video/x-msvideo" = "org.gnome.Showtime.desktop";
          "image/png" = "viewnior.desktop";
          "image/gif" = "viewnior.desktop";
          "image/heic" = "viewnior.desktop";
          "image/jpeg" = "viewnior.desktop";
          "image/svg+xml" = "viewnior.desktop";
          "image/webp" = "viewnior.desktop";
          "text/plain" = "nvim-gui.desktop";
          "text/markdown" = "nvim-gui.desktop";
          "application/x-shellscript" = "nvim-gui.desktop";
          "application/json" = "nvim-gui.desktop";
          "application/xml" = "nvim-gui.desktop";
          "application/zip" = "engrampa.desktop";
          "application/x-zip-compressed" = "engrampa.desktop";
          "application/x-tar" = "engrampa.desktop";
          "application/x-compressed-tar" = "engrampa.desktop";
          "application/x-bzip-compressed-tar" = "engrampa.desktop";
          "application/x-xz-compressed-tar" = "engrampa.desktop";
          "application/x-7z-compressed" = "engrampa.desktop";
          "application/x-rar" = "engrampa.desktop";
          "application/x-rar-compressed" = "engrampa.desktop";
          "x-scheme-handler/magnet" = "transmission-gtk.desktop";
          "x-scheme-handler/http" = "vivaldi-stable.desktop";
          "x-scheme-handler/https" = "vivaldi-stable.desktop";
          "x-scheme-handler/about" = "vivaldi-stable.desktop";
          "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
          "text/html" = "vivaldi-stable.desktop";
        };
      };

      programs.kitty.enable = true; # required for the default Hyprland config
      programs.kitty.font = {
        name = theme.fontMono;
        size = 11;
      };
      # The terminal is the only surface that consumes ANSI colors, so it is
      # where the accent half of `theme` earns its keep.
      programs.kitty.settings = {
        background = theme.background.main;
        foreground = theme.foreground.main;

        color0 = theme.background.light;
        color1 = theme.red;
        color2 = theme.green;
        color3 = theme.yellow;
        color4 = theme.blue;
        color5 = theme.magenta;
        color6 = theme.cyan;
        color7 = theme.foreground.muted;

        color8 = theme.foreground.dark;
        color9 = theme.bright.red;
        color10 = theme.bright.green;
        color11 = theme.bright.yellow;
        color12 = theme.bright.blue;
        color13 = theme.bright.magenta;
        color14 = theme.bright.cyan;
        color15 = theme.foreground.light;
      };
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
        categories = [
          "Utility"
          "TextEditor"
          "Development"
        ];

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
        categories = [
          "Utility"
          "TextEditor"
          "Development"
        ];
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
        categories = [
          "System"
          "FileTools"
          "FileManager"
          "Utility"
          "Core"
        ];
        settings = {
          StartupNotify = "true";
        };
      };

      # Both Print binds save here, and grimblast fails rather than create it.
      systemd.user.tmpfiles.rules = [ "d %h/Screenshots 0755 - - -" ];

      programs.satty = {
        enable = true;
        settings = {
          # Without a command Satty copies through the GTK clipboard, which
          # empties when it exits.
          general.copy-command = "wl-copy";
          font.family = theme.fontUI;
          color-palette.palette = with theme; [
            red
            yellow
            green
            cyan
            blue
            magenta
            foreground.main
          ];
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

          # The primary screen always leads, anchored at the origin; everything
          # else follows it.
          monitor = [ "${cfg.primaryScreen}, ${cfg.primaryMode}, 0x0, 1" ] ++ cfg.extraMonitors;

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
          ];

          general = {
            gaps_in = 5;
            gaps_out = 20;
            border_size = 2;
            "col.active_border" = activeBorder;
            "col.inactive_border" = hyprColor theme.foreground.dark "aa";
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
            kb_layout = if config.base.keyboard.layout == "hallmack" then "us" else "us,ru";
            kb_options = concatStringsSep "," (
              optional (config.base.keyboard.layout != "hallmack") "grp:win_space_toggle"
              ++ optional config.base.keyboard.swapCapsEscape "caps:swapescape"
            );
            follow_mouse = 1;
            # Hyprland applies these to every pointer, the touchpad included;
            # scoping them to the mouse would take a per-device section, whose
            # name is host-specific.
            sensitivity = 0.4;
            accel_profile = "flat";
            touchpad = {
              natural_scroll = false;
              # Hyprland defaults tap-to-click on, which fires clicks from palm
              # brushes while typing.
              "tap-to-click" = false;
              middle_button_emulation = false;
              disable_while_typing = true;
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
              splitKey = if config.base.keyboard.layout == "hallmack" then "L" else "E";
            in
            [
              "$mod, Return, exec, kitty"
              "$mod, Escape, killactive"
              "$mod, D, exec, wofi --show drun"
              "$mod, F, fullscreen"
              "$mod, SPACE, togglefloating"
              "$mod SHIFT, SPACE, exec, hypr-float-here"
              "$mod CTRL, SPACE, exec, hypr-window-class"
              "$mod, P, pseudo"
              "$mod, ${splitKey}, layoutmsg, togglesplit"
              "$mod, M, exec, pwvucontrol"
              "$mod, W, exec, pcmanfm"
              "$mod SHIFT, R, exec, systemctl --user restart quickshell"
              "$mod SHIFT, S, exec, hypr-monitor-scale"
              "$mod, R, submap, resize"
              "$mod, 0, exec, wlogout"

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

              # Special workspace, standing in for i3's scratchpad. S only
              # overlays it; minus stashes a window and pulls one back out,
              # neither of which needs the overlay open.
              "$mod, S, togglespecialworkspace, magic"
              "$mod, minus, exec, hypr-move-to-active-workspace"
              "$mod SHIFT, minus, movetoworkspacesilent, special:magic"

              # Screenshot
              ", Print, exec, screenshot --edit"
              "SHIFT, Print, exec, screenshot"

              # Audio (with notify). The unshifted pair steps by 5% inside
              # `--limit 1.0`. Holding SHIFT deliberately escapes that limit:
              # V climbs past 100%, and C is an absolute assignment that drops
              # straight back to 10% rather than a decrement.
              "$mod, V, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0 && notify-volume"
              "$mod, C, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0 && notify-volume"
              "$mod SHIFT, V, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && notify-volume"
              "$mod SHIFT, C, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10% && notify-volume"
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

            "$mod SHIFT, 0, exec, pidof hyprlock || hyprlock"
          ];

          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
            ", mouse:275, resizewindow"
            ", mouse:276, movewindow"
          ];

          windowrule =
            # Generated rules lead. Apply order is list order and the last match
            # wins a property, so every hand-written rule below stays an override
            # — notably the two that dock under a bar module, which would
            # otherwise be re-centred by their kind.

            # Browse a collection, act once, close.
            map manager [
              "engrampa"
              "pcmanfm"
              "transmission-gtk"
            ]

            # Single-purpose control surface, never compared against a neighbour.
            ++ map utility [
              ".blueman-manager-wrapped"
              "galculator"
              "waypaper"
            ]

            # One piece of content, sized by its own aspect ratio.
            ++ map viewer [
              "com.gabm.satty"
              "org.kde.okular"
              "org.gnome.Showtime"
            ]

            # viewnior opens at GTK's 480x300 default whatever the image, and
            # its own `start-maximized` is eaten by the blanket
            # suppress-maximize rule below, so the size is set here.
            ++ [ (viewer "Viewnior" // { size = "960 600"; }) ]

            # Raised by another window and answered before work continues. These
            # three are standalone agents with no parent to inherit from; the
            # modal rule below covers every dialog that does have one.
            ++ map dialog [
              "gcr-prompter"
              "polkit-gnome-authentication-agent-1"
              "xdg-desktop-portal-gtk"
            ]

            ++ [
              # A modal child is an interruption whatever raised it, so this is the
              # one dialog rule that needs no class list. Browsers that draw their
              # own file chooser in-process are still out of reach.
              {
                name = "dialog-modal";
                "match:modal" = true;
                float = "yes";
                center = true;
              }
              {
                name = "firefox-workspace";
                "match:class" = "^(firefox)$";
                workspace = "1 silent";
              }
              # XWayland reports WM_CLASS's second field, and Hyprland matches
              # case-sensitively, so the class is `Slack`.
              {
                name = "slack-workspace";
                "match:class" = "^(Slack)$";
                workspace = "3 silent";
              }
              (
                {
                  name = "nm-float-pin";
                  "match:class" = "^(nm-connection-editor)$";
                }
                // underBarModule {
                  fromRight = barModuleCentre.network;
                  width = 400;
                  height = 400;
                }
              )
              (
                {
                  name = "pwvucontrol-float-pin";
                  "match:class" = "^(com\\.saivert\\.pwvucontrol)$";
                }
                // underBarModule {
                  fromRight = barModuleCentre.volume;
                  width = 800;
                  height = 500;
                }
              )
              {
                name = "suppress-maximize";
                "match:class" = ".*";
                suppress_event = "maximize";
              }
              {
                name = "fullscreen-idle-inhibit";
                "match:class" = ".*";
                idle_inhibit = "fullscreen";
              }
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
              # No `size`: a rule that sets one wins the initial map and the
              # window then snaps back to what wofi asks for. Callers passing
              # `--width`/`--lines`, as hypr-monitor-scale does, need theirs.
              {
                name = "wofi-float";
                "match:class" = "^(wofi)$";
                center = true;
                float = "yes";
                pin = "yes";
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
          # Percentages, not pixels: Hyprland rejects a grow delta larger than
          # the window itself, which a fixed step hits on short splits.
          submap = resize
          binde = , ${dirs.l}, resizeactive, -10% 0
          binde = , ${dirs.d}, resizeactive, 0 10%
          binde = , ${dirs.u}, resizeactive, 0 -10%
          binde = , ${dirs.r}, resizeactive, 10% 0
          binde = , left, resizeactive, -10% 0
          binde = , down, resizeactive, 0 10%
          binde = , up, resizeactive, 0 -10%
          binde = , right, resizeactive, 10% 0
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
        /* The window is the only painted surface. Every box inside it is
           transparent, so the launcher background is stated once and a change
           to `theme` cannot leave one layer behind. */
        window {
          font-family: "${theme.fontUI}", monospace;
          font-size: 17px;
          letter-spacing: 0.2px;
          margin: 0px;
          background-color: ${theme.background.light};
          border-radius: 10px;
        }

        #outer-box,
        #inner-box,
        #scroll,
        #entry {
          background-color: transparent;
          border: none;
        }

        #inner-box {
          margin: 0 8px 8px;
        }

        #scroll {
          max-height: 300px;
        }

        #input {
          margin: 14px 8px;
          border: none;
          color: ${theme.foreground.main};
        }

        #text {
          margin: 0px 6px;
          border: none;
          color: ${theme.foreground.main};
        }

        /* The selected row is the one place a second color is wanted, so it
           takes the accent rather than a second shade of the background: two
           near-identical greys is what made the selection vanish. */
        #entry:selected {
          background-color: ${theme.blue};
          border-radius: 6px;
        }

        #entry:selected #text,
        #entry:selected > * {
          color: ${theme.background.main};
        }
      '';

      # https://github.com/end-4/dots-hyprland/blob/main/dots/.config/kitty/kitty.conf
      # https://github.com/end-4/dots-hyprland/blob/main/dots/.config/wlogout/style.css
      xdg.configFile."wlogout/layout".text = lib.concatMapStrings (entry: builtins.toJSON entry + "\n") [
        {
          label = "lock";
          action = "hyprlock";
          text = "Lock";
          keybind = "l";
        }
        {
          label = "hibernate";
          action = "systemctl hibernate";
          text = "Hibernate";
          keybind = "h";
        }
        {
          label = "logout";
          action = "loginctl terminate-user $USER";
          text = "Logout";
          keybind = "e";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutdown";
          keybind = "s";
        }
        {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "u";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot";
          keybind = "r";
        }
      ];

      xdg.configFile."wlogout/style.css".text = ''
        * {
          font-family: "${theme.fontMono}", monospace;
          background-image: none;
        }

        window {
          background-color: ${rgba theme.background.main "0.92"};
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
          background = [
            {
              monitor = "";
              path = "screenshot";
              blur_passes = 3;
              blur_size = 7;
              brightness = 0.5;
            }
          ];
          input-field = [
            {
              monitor = "";
              size = "300, 50";
              outline_thickness = 2;
              dots_spacing = 0.3;
              outer_color = activeBorder;
              inner_color = "rgba(0, 0, 0, 0.0)";
              font_color = hyprColor theme.foreground.main "ff";
              fade_on_empty = false;
              placeholder_text = "Password...";
              rounding = 15;
              position = "0, -60";
              halign = "center";
              valign = "center";
            }
          ];
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

      # Idle and suspend handling. `lock_cmd` answers logind's Lock signal, and
      # `before_sleep_cmd` raises the lock before the machine suspends so a
      # resume never lands on an unlocked desktop.
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch dpms on";
          };
          # One listener per distinct step and threshold. The suspend turns the
          # screen off.
          listener = unique (
            concatLists (
              mapAttrsToList (
                _:
                mapAttrsToList (
                  step: timeout: {
                    inherit timeout;
                    on-timeout = "${idleStep} ${step} ${toString timeout}";
                    on-resume = "hyprctl keyword decoration:screen_shader '[[EMPTY]]'";
                  }
                )
              ) idleTimeouts
            )
          );
        };
      };

      programs.vifm = {
        enable = true;

        extraConfig = ''
          filetype *.pdf,*.jpg,*.jpeg,*.png,*.gif xdg-open %f &

          ${
            if config.base.keyboard.layout == "hallmack" then
              ''
                nnoremap H L
                nnoremap L H
                nnoremap j <nop>
                nnoremap k <nop>
              ''
            else
              ""
          }
        '';
      };

      dconf = {
        enable = true;
        # Keys are dconf paths: the separator is a slash, and a dotted name is
        # written verbatim into a group no schema reads.
        settings."org/gnome/desktop/wm/preferences".button-layout = "appmenu:close";
        settings."org/gnome/desktop/interface" = {
          overlay-scrolling = false;
          # libadwaita ignores gtk.theme; dark mode comes from this preference.
          color-scheme = "prefer-dark";
        };
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
          # Chromium clients draw their own buttons but read this, so it is what
          # strips minimize and maximize from Vivaldi.
          "gtk-decoration-layout" = "appmenu:close";
        };
        gtk4 = {
          theme = null;
          extraConfig = {
            "gtk-overlay-scrolling" = false;
            "gtk-decoration-layout" = "appmenu:close";
          };
        };
      };

      home.pointerCursor = {
        gtk.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 17;
      };

      # A single `-d` covers both edges, so the intended 30 min / 2 h split is
      # folded into one 2 h transition: warm-up ends 07:00, dimming runs
      # 18:30 .. 20:30.
      systemd.user.services.wlsunset = {
        Unit = {
          Description = "Day/night colour temperature (wlsunset)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service.ExecStart = "${pkgs.wlsunset}/bin/wlsunset -S 07:00 -s 18:30 -T 6500 -t 3500 -d 7200";
        Install.WantedBy = [ "graphical-session.target" ];
      };

      services.dunst = {
        enable = true;

        settings = {
          global = {
            # `follow` is what takes keyboard/mouse; setting it overrides
            # `monitor`, which wants an output name or index instead.
            follow = "keyboard";
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
