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

  hyprColor = import ../../lib/hypr-color.nix lib;

  # Hyprland's colors under each color scheme. The background is the one
  # Quickshell's login curtain maps in.
  hyprColors = mapAttrs (_: p: {
    general.col = {
      active_border = hyprColor p.blue "ff";
      inactive_border = hyprColor p.foreground.faint "aa";
    };
    misc.background_color = hyprColor p.background.desktop "ff";
  }) { inherit (theme) dark light; };

  # kitty's colors under each color scheme. Its own cursor and selection are
  # made for a dark background, so the light scheme sets them too.
  kittyColors =
    let
      colors = p: {
        background = p.background.main;
        foreground = p.foreground.main;
        color0 = p.black;
        color1 = p.red;
        color2 = p.green;
        color3 = p.yellow;
        color4 = p.blue;
        color5 = p.magenta;
        color6 = p.cyan;
        color7 = p.white;
        color8 = p.bright.black;
        color9 = p.bright.red;
        color10 = p.bright.green;
        color11 = p.bright.yellow;
        color12 = p.bright.blue;
        color13 = p.bright.magenta;
        color14 = p.bright.cyan;
        color15 = p.bright.white;
      };
    in
    {
      dark = colors theme.dark;
      light = colors theme.light // {
        cursor = theme.light.foreground.main;
        cursor_text_color = theme.light.background.main;
        selection_background = theme.light.bright.white;
        selection_foreground = "none";
      };
    };
  kittyTheme = colors: concatStrings (mapAttrsToList (k: v: "${k} ${v}\n") colors);

  gtkSchemes = {
    dark = {
      theme = "Materia-dark-compact";
      icons = "Papirus-Dark";
    };
    light = {
      theme = "Materia-light-compact";
      icons = "Papirus-Light";
    };
  };

  # Quickshell and Hyprland's config read the saved scheme; kitty, libadwaita
  # and the browsers follow GTK's `color-scheme` through the portal.
  colorScheme = pkgs.writeShellApplication {
    name = "color-scheme";
    runtimeInputs = [
      pkgs.dconf
      config.programs.hyprland.package
    ];
    text =
      let
        values =
          scheme:
          "gtk=${gtkSchemes.${scheme}.theme} icons=${gtkSchemes.${scheme}.icons} hypr=${escapeShellArg "hl.config(${generators.toLua { multiline = false; } hyprColors.${scheme}})"}";
      in
      ''
        file=''${XDG_STATE_HOME:-$HOME/.local/state}/color-scheme
        saved=$(cat "$file" 2>/dev/null || true)
        [ "$saved" = light ] || saved=dark

        case ''${1:-$saved} in
          light | dark) scheme=''${1:-$saved} ;;
          toggle) if [ "$saved" = light ]; then scheme=dark; else scheme=light; fi ;;
          *)
            echo "usage: color-scheme [light | dark | toggle]" >&2
            exit 2
            ;;
        esac
        if [ "$scheme" = light ]; then
          ${values "light"}
        else
          ${values "dark"}
        fi

        mkdir -p "$(dirname "$file")"
        echo "$scheme" >"$file"

        printf '%s\n' '[/]' "color-scheme='prefer-$scheme'" "gtk-theme='$gtk'" "icon-theme='$icons'" |
          dconf load /org/gnome/desktop/interface/
        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          hyprctl eval "$hypr" >/dev/null
        fi
      '';
  };

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

  # The keyboard and pointer, at the greeter as in the session.
  hyprInput = {
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
      tap_to_click = false;
      middle_button_emulation = false;
      disable_while_typing = true;
    };
  };

  # The primary screen always leads, anchored at the origin; everything else
  # follows it.
  monitors = [
    {
      output = cfg.primaryScreen;
      mode = cfg.primaryMode;
      position = "0x0";
      scale = 1;
    }
  ]
  ++ cfg.extraMonitors;

  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
  };

  # greetd's greeter: Quickshell's login screen in a Hyprland of its own, with
  # the session's screens, keys, pointer and background, which exits once
  # Quickshell does, as it does on launching the session. These monitor rules
  # are its defaults, over which Quickshell applies the last user's layout.
  greeterHyprland =
    let
      lua = generators.toLua { };
      hyprctl = getExe' config.programs.hyprland.package "hyprctl";
    in
    pkgs.writeText "greeter.lua" ''
      ${concatMapStrings (m: "hl.monitor(${lua m})\n") monitors}
      hl.env("XCURSOR_PATH", "${cursor.package}/share/icons")
      hl.env("XCURSOR_THEME", "${cursor.name}")
      hl.env("XCURSOR_SIZE", "24")

      hl.config(${
        lua {
          input = hyprInput;
          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            background_color = hyprColor theme.dark.background.desktop "ff";
          };
          ecosystem = {
            no_donation_nag = true;
            no_update_news = true;
          };
          # Off the card while the password is typed.
          cursor.hide_on_key_press = true;
          # The login screen fades itself in.
          animations.enabled = false;
        }
      })

      hl.on("hyprland.start", function()
        hl.exec_cmd(${lua "${getExe pkgs.quickshell} -p ${config.my.quickshell.greeter}; ${hyprctl} dispatch 'hl.dsp.exit()'"})
      end)
    '';

  waitForSni = pkgs.writeShellScript "wait-for-sni" ''
    until ${lib.getExe' pkgs.dbus "dbus-send"} --session --print-reply \
        --dest=org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus.GetNameOwner \
        string:org.kde.StatusNotifierWatcher 2>/dev/null; do
      sleep 1
    done
  '';

  clipboardPersistCb = pkgs.writeShellScript "clipboard-persist-cb" ''
    types=$(${lib.getExe' pkgs.wl-clipboard "wl-paste"} --list-types 2>/dev/null)
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
    [ "$(${lib.getExe' pkgs.wl-clipboard "wl-paste"} --no-newline | wc -c)" -eq 0 ] && exit 0

    ${lib.getExe' pkgs.wl-clipboard "wl-paste"} --no-newline \
      | ${lib.getExe' pkgs.wl-clipboard "wl-copy"} --foreground &
    echo $! > "$pid_file"
  '';

  # The strip of each bar, top and bottom, which Quickshell is built to and
  # reserves as its exclusive zone.
  barHeight = 51;

  # Between the windows and the screen's edges or the bars. The bars' segments
  # line up with it at the sides.
  outerGap = 10;

  wallpaperDir = u: "${u.homedir}/Pictures/Wallpapers";

  # Centre of each module a window docks to, in px from the screen's right
  # edge, measured off the bottom bar: Hyprland cannot read the layout.
  barModuleCentre = {
    # The battery segment sits between volume and the corner on a laptop.
    volume = if config.base.isLaptop then 348 else 242;
  };

  # Floats a window over the bottom bar, centred on the module that opens it
  # unless that would take it past the outer gap on the right.
  dockToBarModule =
    {
      fromRight,
      width,
      height,
    }:
    {
      float = true;
      pin = true;
      move = "(monitor_w-${
        toString (lib.max (fromRight + width / 2) (width + outerGap))
      }) (monitor_h-${toString (barHeight + height)})";
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
      match.class = "(?i)^(${escapeRegex class})$";
      float = true;
      center = true;
    }
    // props;

  # A fraction of the display, not pixels: one module serves fractal's 2560x1440
  # and the thinkpad's panel, so a constant is right on at most one of them.
  # `size` is evaluated by muParser over `monitor_w`/`monitor_h`, so a term
  # carries no spaces and a percentage would throw at map time.
  manager = floatRule "manager" { size = "monitor_w*0.47 monitor_h*0.62"; };
  utility = floatRule "utility" { size = "monitor_w*0.23 monitor_h*0.35"; };

  # The content sets the shape, so none is imposed beyond `fitWorkArea`.
  viewer = floatRule "viewer" { };
  dialog = floatRule "dialog" { };

  # The size a client asks for, cut to the work area: GTK's file chooser
  # restores one saved at another scale. It must lead the rules, so any `size`
  # after it overrides it. Every class matches because a static rule never sees
  # `match:float`, and Hyprland reads `size` only for floats and pseudotiles.
  # `max_size` would not hold, since float placement undoes its clamp.
  fitWorkArea = {
    name = "fit-work-area";
    match.class = ".*";
    size = "min(window_w,monitor_w-${toString (2 * outerGap)}) min(window_h,monitor_h-${
      toString (2 * (barHeight + outerGap))
    })";
  };

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

  # Lua that sets the screen shader. Hyprland 0.56.2 repaints only two of an
  # output's three buffers on a shader change, so the third flashes the old
  # shader every third frame. Writing master's mfact back to itself makes
  # Hyprland repaint every monitor in full. Remove that write once Hyprland
  # includes a287842067 (hyprwm/Hyprland#15924), which no release past 0.56.2
  # has yet.
  setScreenShader =
    path:
    ''hl.config({ decoration = { screen_shader = "${path}" }, master = { mfact = hl.get_config("master.mfact") } })'';

  # Minutes of idle before each step, per power profile.
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

  # In seconds. A suspend in the lock's minute trails it by 5 s, so the lock
  # screen is up before the outputs go dark.
  idleTimeouts = mapAttrs (_: m: {
    dim = m.dim * 60;
    lock = m.lock * 60;
    suspend = m.suspend * 60 + (if m.suspend == m.lock then 5 else 0);
  }) idleMinutes;

  # The idle suspend, which on a host that hibernates hibernates after
  # HibernateDelaySec.
  suspendVerb = if config.base.hibernate then "suspend-then-hibernate" else "suspend";

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

      # With the lid closed on another monitor the laptop stays up, and the
      # suspend only turns the screens off.
      clamshell="$(printf 'b true\nb true')"

      case $1 in
        dim) [ "$2" -ge "$dim" ] && hyprctl eval '${setScreenShader dimShader}' ;;
        lock) [ "$2" -ge "$lock" ] && loginctl lock-session ;;
        suspend)
          [ "$2" -ge "$suspend" ] || exit 0
          if [ "$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed Docked)" = "$clamshell" ]; then
            hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
          else
            # A block-mode sleep lock, as Claude Code's awake plugin holds,
            # refuses the suspend and hypridle never asks again, so one step
            # waits it out until input ends the idle; a second would suspend
            # again on the wake.
            exec 9>"$XDG_RUNTIME_DIR/idle-suspend.lock"
            flock -n 9 || exit 0
            while systemd-inhibit --list --json=short | ${lib.getExe pkgs.jq} -e 'any(.[]; .mode == "block" and (.what | split(":") | index("sleep")))' >/dev/null; do
              sleep 5
            done
            systemctl ${suspendVerb}
          fi
          ;;
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
    exec ${lib.getExe pkgs.kitty} -d /etc/nixos -e ${lib.getExe pkgs.zsh}
  '';

in
{
  options.my.desktop = {
    enable = mkEnableOption "Wayland Hyprland desktop environment";

    primaryScreen = mkOption {
      type = types.str;
      default = "eDP-1";
      description = "Wayland connector name of the screen that carries the bar and tray, or `desc:` and the start of its description.";
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
      type = types.listOf (types.attrsOf types.anything);
      default = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
        }
      ];
      example = [
        {
          output = "DP-1";
          mode = "1920x1080@60";
          position = "2560x0";
          scale = 1;
        }
      ];
      description = ''
        `hl.monitor` specs for the outputs other than the primary, emitted
        after it. The primary is always generated from `primaryScreen` and
        `primaryMode`, so populating this list cannot silently drop it.
        The default catch-all gives any further display its preferred mode,
        placed to the right; replace it to position additional screens exactly.
      '';
    };

    colorSchemeCommand = mkOption {
      type = types.str;
      readOnly = true;
      default = getExe colorScheme;
      description = "Command that sets the color scheme, `light`, `dark` or `toggle`, or with no argument sets the saved one again.";
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
      inherit barHeight outerGap;
      firstDayOfWeek = "monday";
      worldClocks = [ "Europe/Minsk" ];
    };

    # Enabled for the libinput udev rules only. The `mouse` and `touchpad`
    # option trees are gated on `services.xserver.enable` in nixpkgs, so they
    # are inert on Wayland; pointer behaviour lives in Hyprland's `input` block.
    services.libinput.enable = true;

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };

    # A Hyprland of its own rather than the kernel console, whose fbcon locks
    # its character grid in at boot and never re-probes, or cage, which spans
    # one window across every screen. The greeter's home keeps what Hyprland
    # and Quickshell write, the last user and session among it.
    services.greetd = {
      enable = true;
      settings.default_session.command = "${getExe' config.programs.hyprland.package "start-hyprland"} -- --config ${greeterHyprland}";
    };
    users.users.greeter = {
      home = "/var/lib/greeter";
      createHome = true;
    };

    # What the greeter offers a user it has not seen log in. `withUWSM`
    # publishes both a plain and a uwsm-managed Hyprland session; the plain one
    # leaves the compositor a child of greetd, logging to the VT instead of the
    # journal, with no systemd user units.
    services.displayManager.defaultSession = "hyprland-uwsm";

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

    # The terminal uwsm opens a `Terminal=true` desktop entry in, as the
    # launcher starts every app through it.
    xdg.terminal-exec = {
      enable = true;
      settings.default = [ "kitty.desktop" ];
    };

    environment.systemPackages = with pkgs; [
      kitty.terminfo

      obsidian
      dconf
      ntfs3g
      brightnessctl
      playerctl # backs the XF86Audio{Play,Pause,Prev,Next} binds

      # Classifying a program means knowing the class it actually reports, which
      # is not derivable from its name: viewnior answers `Viewnior` under
      # XWayland, okular `org.kde.okular`, and blueman leaks its Nix wrapper.
      (writeShellScriptBin "hypr-window-class" ''
        hyprctl activewindow -j \
          | ${lib.getExe pkgs.jq} -r '"class: \(.class)\ninitialClass: \(.initialClass)\nxwayland: \(.xwayland)"' \
          | xargs -0 notify-send --app-name=Hyprland "Window class" --urgency normal --hint string:synchronous:my_class
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
          | ${lib.getExe pkgs.jq} -r 'select(.workspace.name == "special:magic") | .address // empty')

        if [ -z "$ADDRESS" ]; then
          ADDRESS=$(hyprctl clients -j \
            | ${lib.getExe pkgs.jq} -r 'map(select(.workspace.name == "special:magic")) | .[0].address // empty')
        fi

        if [ -z "$ADDRESS" ]; then
          notify-send --app-name=Hyprland "Scratchpad" "Empty" --urgency low --hint string:synchronous:my_scratchpad
          exit 0
        fi

        # `activeworkspace` keeps reporting the real workspace while the
        # special one is overlaid, so it is always a valid destination.
        WORKSPACE=$(hyprctl activeworkspace -j | ${lib.getExe pkgs.jq} -r '.id')

        hyprctl dispatch "hl.dsp.window.move({ workspace = $WORKSPACE, window = \"address:$ADDRESS\" })"
      '')

      # Saves an area capture and copies its path. With `--edit`, Satty opens
      # it first and saves over it, so the path is valid however Satty is
      # left, edited or not. The path then takes the clipboard unless Satty's
      # own copy already put the image there.
      (writeShellScriptBin "screenshot" ''
        FILE="$(${lib.getExe' pkgs.xdg-user-dirs "xdg-user-dir"} SCREENSHOTS)/$(date +%Y%m%d_%H%M%S).png"
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
        notify-send --app-name=Hyprland "Screenshot path copied" "$FILE" --urgency low --hint string:synchronous:my_screenshot
      '')

      wl-clipboard
      cliphist
    ];

    # Vendor-neutral: the driver, its VA-API backend and any vendor session
    # variables belong to the host.
    hardware.graphics.enable = true;

    # Paired with the ntfs3g package below; the in-kernel ntfs3 driver loses to it.
    boot.blacklistedKernelModules = [ "ntfs3" ];

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

    # `color-scheme` owns the color scheme's dconf keys, which a fresh home lacks.
    home-manager.sharedModules = [
      (
        { lib, ... }:
        {
          home.activation.colorScheme = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
            if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then
              run ${getExe colorScheme}
            else
              run ${getExe' pkgs.dbus "dbus-run-session"} --dbus-daemon=${getExe' pkgs.dbus "dbus-daemon"} ${getExe colorScheme}
            fi
          '';
        }
      )
    ];

    home-manager.users = forAllUsers (u: {
      home.packages = with pkgs; [
        colorScheme
        hyprgraphics
        hyprpicker
        grim
        slurp
        wlsunset
        xdg-desktop-portal-hyprland

        (vivaldi.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            ui=$out/opt/vivaldi/resources/vivaldi
            cp ${./vivaldi-color-scheme.js} $ui/color-scheme.js
            # Deferred: the core fills each window's body as the window opens,
            # and a window whose body a blocking script holds back opens blank,
            # as an extension's popup did.
            substituteInPlace $ui/window.html \
              --replace-fail '</head>' '<script src="color-scheme.js" defer></script></head>'
          '';
        }))
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
        engrampa
        p7zip
        unrar
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
        snapshot

        (writeShellScriptBin "cps" "2>/dev/null 1>/dev/null kitty -d $PWD & disown")
        nxe
      ];

      services.udiskie = {
        enable = true;
        automount = true;
        notify = true;
      };

      xdg.configFile."cliphist/config".text = ''
        max-items 300
      '';
      # Holds no process: stopping with the graphical session, at logout or
      # shutdown, wipes the clipboard history. A rebuild never restarts it, so
      # a cliphist update wipes nothing.
      systemd.user.services.cliphist-wipe = {
        Unit = {
          Description = "Wipe the clipboard history at logout";
          PartOf = [ "graphical-session.target" ];
          X-SwitchMethod = "keep-old";
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "${lib.getExe pkgs.cliphist} wipe";
        };
        Install.WantedBy = [ "graphical-session.target" ];
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

      # https://github.com/end-4/dots-hyprland/blob/main/dots/.config/kitty/kitty.conf
      programs.kitty.enable = true; # required for the default Hyprland config
      programs.kitty.font = {
        name = theme.fontMono;
        size = 11;
      };
      programs.kitty.settings = kittyColors.dark // {
        # Inconsolata LGC 3.x cut its line height from 1.48 em to 1.11 em; this
        # restores the 1.x spacing.
        modify_font = "cell_height 133%";
      };
      # kitty follows the portal's `color-scheme`, which `color-scheme` sets,
      # and tells the programs inside, Neovim among them. Each file replaces
      # every color kitty.conf sets.
      xdg.configFile."kitty/dark-theme.auto.conf".text = kittyTheme kittyColors.dark;
      xdg.configFile."kitty/no-preference-theme.auto.conf".text = kittyTheme kittyColors.dark;
      xdg.configFile."kitty/light-theme.auto.conf".text = kittyTheme kittyColors.light;
      programs.kitty.keybindings = {
        "ctrl+shift+enter" = "no_op";
        "ctrl+shift+]" = "no_op";
        "ctrl+shift+[" = "no_op";
        "ctrl+shift+`" = "no_op";
        "ctrl+shift+w" = "no_op";
      };

      xdg.desktopEntries.nvim-gui = {
        name = "Neovim";
        comment = "Open file in Neovim within default terminal";
        type = "Application";
        terminal = false;
        icon = "nvim";
        categories = [
          "Utility"
          "TextEditor"
          "Development"
        ];

        exec = "${lib.getExe pkgs.kitty} nvim %f";

        mimeType = [
          "text/plain"
          "text/markdown"
          "application/x-shellscript"
          "application/json"
          "application/xml"
        ];
      };

      # The Neovim wrapper's own entry, which would list beside the one above,
      # hidden from menus but kept for the file types it claims.
      xdg.dataFile."applications/nvim.desktop".source = pkgs.runCommand "nvim.desktop" { } ''
        sed '0,/^\[Desktop Entry\]$/s//&\nNoDisplay=true/' \
          ${
            config.home-manager.users.${u.name}.programs.neovim.finalPackage
          }/share/applications/nvim.desktop > $out
      '';

      xdg.desktopEntries.nxe = {
        name = "nxe";
        genericName = "NixOS Configuration";
        comment = "Edit the NixOS configuration in vim";
        type = "Application";
        terminal = false;
        icon = "nvim";
        exec = lib.getExe nxe;
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

      # Created at activation: both Print binds save to SCREENSHOTS, and
      # grimblast fails rather than create it.
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = false;
        publicShare = null;
        templates = null;
        extraConfig = {
          SCREENSHOTS = "${u.homedir}/Pictures/Screenshots";
          WALLPAPERS = wallpaperDir u;
        };
      };

      programs.satty = {
        enable = true;
        settings = {
          # Without a command Satty copies through the GTK clipboard, which
          # empties when it exits.
          general.copy-command = "wl-copy";
          font.family = theme.fontUI;
          color-palette.palette = with theme.dark; [
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
        configType = "lua";
        # Use the Hyprland and portal packages from the NixOS module
        package = null;
        portalPackage = null;

        # UWSM brings `graphical-session.target` up itself. The stop below
        # propagates to that target and cancels UWSM's pending start of it,
        # which takes the compositor down with it, so a UWSM session skips the
        # restart; the plain session needs it for the user units.
        systemd.extraCommands = [
          ''[ -z "$UWSM_FINALIZE_VARNAMES" ]''
          "systemctl --user stop hyprland-session.target"
          "systemctl --user start hyprland-session.target"
        ];

        # Data, which home-manager renders as one `hl.<name>(...)` call per
        # entry; `curve` leads through `importantPrefixes`, so an animation can
        # name it. Binds, the resize submap and startup are code, in
        # `extraConfig`.
        settings = {
          # A layout saved from the bar's monitor panel replaces these for its
          # set of monitors, and again after a reload.
          monitor = monitors;

          env = [
            {
              _args = [
                "XCURSOR_SIZE"
                "24"
              ];
            }
            {
              _args = [
                "HYPRCURSOR_SIZE"
                "24"
              ];
            }
          ];

          config = {
            general = {
              gaps_in = 5;
              gaps_out = outerGap;
              border_size = 2;
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

            input = hyprInput;

            gestures = {
              workspace_swipe_distance = 500;
              workspace_swipe_create_new = true;
            };

            dwindle.preserve_split = true;
            master.new_status = "master";

            # Until awww maps, a plain background rather than Hyprland's own
            # wallpaper, whose colour `extraConfig` sets. The bar holds the
            # session lock, and one restarted under it takes the lock back.
            misc = {
              disable_hyprland_logo = true;
              disable_splash_rendering = true;
              allow_session_lock_restore = true;
            };

            # No donation or update-news windows at login.
            ecosystem = {
              no_donation_nag = true;
              no_update_news = true;
            };

            animations.enabled = true;
          };

          curve._args = [
            "snappy"
            {
              type = "bezier";
              points = [
                [
                  0.2
                  1
                ]
                [
                  0.2
                  1
                ]
              ];
            }
          ];

          gesture = {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          };

          animation = [
            {
              leaf = "windows";
              enabled = true;
              speed = 10;
              bezier = "snappy";
              style = "popin 80%";
            }
            {
              leaf = "fade";
              enabled = true;
              speed = 3;
              bezier = "snappy";
            }
            {
              leaf = "workspaces";
              enabled = true;
              speed = 10;
              bezier = "snappy";
              style = "slide";
            }
          ];

          # Quickshell's panels and notification popups animate themselves,
          # sliding out of the bar. Both sit on `overlay`, where Hyprland draws
          # a higher `order` first, so the popups go beneath the panels.
          layer_rule = [
            {
              name = "quickshell-panel";
              match.namespace = "^(quickshell-panel)$";
              no_anim = true;
            }
            {
              name = "quickshell-notifications";
              match.namespace = "^(quickshell-notifications)$";
              no_anim = true;
              order = 1;
            }
            # The launcher's dim, beneath the popups and the panels, fades
            # itself with the launcher.
            {
              name = "quickshell-dim";
              match.namespace = "^(quickshell-dim)$";
              no_anim = true;
              order = 2;
            }
            # awww animates its own changes, so its first image shows the
            # moment `openlayer` reports it.
            {
              name = "awww";
              match.namespace = "^(awww-daemon)$";
              no_anim = true;
            }
            # The login curtain, above every other layer, maps unseen over the
            # plain background and fades itself.
            {
              name = "quickshell-curtain";
              match.namespace = "^(quickshell-curtain)$";
              no_anim = true;
              order = -1;
            }
          ];

          window_rule =
            # Generated rules lead. Apply order is list order and the last match
            # wins a property, so every hand-written rule below stays an override
            # — notably the two that dock to a bar module, which would
            # otherwise be re-centred by their kind.
            [ fitWorkArea ]

            # Browse a collection, act once, close.
            ++ map manager [
              "engrampa"
              "pcmanfm"
              "transmission-gtk"
            ]

            # Single-purpose control surface, never compared against a neighbour.
            ++ map utility [
              ".blueman-manager-wrapped"
              "galculator"
              "nm-connection-editor"
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
                match.modal = true;
                float = true;
                center = true;
              }
              {
                name = "firefox-workspace";
                match.class = "^(firefox)$";
                workspace = "1 silent";
              }
              # XWayland reports WM_CLASS's second field, and Hyprland matches
              # case-sensitively, so the class is `Slack`.
              {
                name = "slack-workspace";
                match.class = "^(Slack)$";
                workspace = "3 silent";
              }
              (
                {
                  name = "pwvucontrol-float-pin";
                  match.class = "^(com\\.saivert\\.pwvucontrol)$";
                }
                // dockToBarModule {
                  fromRight = barModuleCentre.volume;
                  width = 800;
                  height = 500;
                }
              )
              {
                name = "suppress-maximize";
                match.class = ".*";
                suppress_event = "maximize";
              }
              {
                name = "fullscreen-idle-inhibit";
                match.class = ".*";
                idle_inhibit = "fullscreen";
              }
              {
                name = "fix-xwayland-drags";
                match = {
                  class = "^$";
                  float = true;
                  fullscreen = false;
                  pin = false;
                  title = "^$";
                  xwayland = true;
                };
                no_focus = true;
              }
              {
                name = "stretchly-break";
                match = {
                  class = "^electron$";
                  title = "^Time to take a break!$";
                };
                center = true;
                pin = true;
                dim_around = true;
              }
            ];
        };

        extraConfig =
          let
            lua = generators.toLua { };
            splitKey = if config.base.keyboard.layout == "hallmack" then "L" else "E";

            startup = [
              "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
              # NetworkManager's secret agent, which asks for VPN, 802.1X and
              # changed Wi-Fi secrets. Quickshell hides its tray icon.
              "${waitForSni} && ${lib.getExe pkgs.networkmanagerapplet}"
              "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
              "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --watch ${clipboardPersistCb}"
              "wl-paste --type text --watch cliphist store"
              "wl-paste --type image --watch cliphist store"
            ];
          in
          ''
            local mod = "ALT"
            local exec = hl.dsp.exec_cmd

            -- The borders and background under the color scheme
            -- `color-scheme` saved, which sets them again on a change.
            do
              local state = os.getenv("XDG_STATE_HOME")
              if not state or state == "" then
                state = os.getenv("HOME") .. "/.local/state"
              end
              local file = io.open(state .. "/color-scheme")
              local scheme = file and file:read("l")
              if file then
                file:close()
              end
              hl.config(scheme == "light" and ${lua hyprColors.light} or ${lua hyprColors.dark})
            end

            -- The pointer stays hidden until Quickshell's login curtain fades,
            -- which shows it again; the timer does should the bar never get
            -- that far. A reload resets the option and drops the timer.
            hl.on("hyprland.start", function()
              hl.config({ cursor = { invisible = true } })
              hl.timer(function()
                hl.config({ cursor = { invisible = false } })
              end, { timeout = 10000, type = "oneshot" })
            ${concatMapStrings (command: "  hl.exec_cmd(${lua command})\n") startup}end)

            -- `togglefloating` floats a window at whatever geometry its tile
            -- happened to have, which is the geometry being escaped. This lands
            -- it where the manager kind would have, for the windows no rule
            -- caught. A monitor reports its size in pixels, which its scale
            -- takes back to the logical size the rules measure in.
            local function float_here()
              local monitor = hl.get_active_monitor()
              if not monitor then
                return
              end
              hl.dispatch(hl.dsp.window.float({ action = "enable" }))
              hl.dispatch(hl.dsp.window.resize({
                x = monitor.width / monitor.scale * 0.47,
                y = monitor.height / monitor.scale * 0.62,
              }))
              hl.dispatch(hl.dsp.window.center())
            end

            -- Grows the focused window by a fraction of its own size. Fractions,
            -- not pixels: Hyprland rejects a grow delta larger than the window
            -- itself, which a fixed step hits on short splits.
            local function grow(fx, fy)
              return function()
                local window = hl.get_active_window()
                if window then
                  hl.dispatch(hl.dsp.window.resize({
                    x = fx * window.size.x,
                    y = fy * window.size.y,
                    relative = true,
                  }))
                end
              end
            end

            hl.bind(mod .. " + Return", exec("kitty"))
            hl.bind(mod .. " + Escape", hl.dsp.window.close())
            hl.bind(mod .. " + D", exec("quickshell ipc call launcher toggle apps"))
            hl.bind(mod .. " + Y", exec("quickshell ipc call launcher toggle clipboard"))
            hl.bind(mod .. " + period", exec("quickshell ipc call launcher toggle symbols"))
            hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
            hl.bind(mod .. " + SPACE", hl.dsp.window.float())
            hl.bind(mod .. " + SHIFT + SPACE", float_here)
            hl.bind(mod .. " + CTRL + SPACE", exec("hypr-window-class"))
            hl.bind(mod .. " + P", hl.dsp.window.pseudo())
            hl.bind(mod .. " + ${splitKey}", hl.dsp.layout("togglesplit"))
            hl.bind(mod .. " + M", exec("pwvucontrol"))
            hl.bind(mod .. " + W", exec("pcmanfm"))
            hl.bind(mod .. " + SHIFT + R", exec("systemctl --user restart quickshell"))
            hl.bind(mod .. " + grave", exec("quickshell ipc call notifications dismiss"))
            hl.bind(mod .. " + SHIFT + grave", exec("quickshell ipc call notifications dismissAll"))
            hl.bind(mod .. " + CTRL + grave", exec("quickshell ipc call notifications toggle"))
            hl.bind(mod .. " + SHIFT + S", exec("quickshell ipc call monitors toggle"))
            hl.bind(mod .. " + SHIFT + W", exec("quickshell ipc call wallpapers toggle"))
            hl.bind(mod .. " + SHIFT + T", exec("quickshell ipc call todoist toggle"))
            hl.bind(mod .. " + R", hl.dsp.submap("resize"))
            hl.bind(mod .. " + 0", exec("quickshell ipc call session toggle"))

            -- Focus, and with SHIFT move, by the layout's direction keys and the
            -- arrows alike.
            for _, keys in ipairs({
              { "${dirs.l}", "left", "l" },
              { "${dirs.d}", "down", "d" },
              { "${dirs.u}", "up", "u" },
              { "${dirs.r}", "right", "r" },
            }) do
              for _, key in ipairs({ keys[1], keys[2] }) do
                hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = keys[3] }))
                hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = keys[3] }))
              end
            end

            for i = 1, 9 do
              hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
              hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
              hl.bind(mod .. " + CTRL + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
            end

            -- Workspace back/forth
            hl.bind(mod .. " + B", hl.dsp.focus({ workspace = "previous" }))
            hl.bind(mod .. " + SHIFT + B", hl.dsp.window.move({ workspace = "previous" }))

            -- Special workspace, standing in for i3's scratchpad. S only
            -- overlays it; minus stashes a window and pulls one back out,
            -- neither of which needs the overlay open.
            hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
            hl.bind(mod .. " + minus", exec("hypr-move-to-active-workspace"))
            hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:magic", follow = false }))

            hl.bind("Print", exec("screenshot --edit"))
            hl.bind("SHIFT + Print", exec("screenshot"))

            -- Audio, each raising the OSD. SHIFT C is an absolute assignment
            -- that drops straight back to 10% rather than a decrement. The
            -- unshifted pair steps by 5% inside `--limit 1.0`; SHIFT V
            -- deliberately escapes that limit and climbs past 100%.
            hl.bind(mod .. " + SHIFT + C", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10% && quickshell ipc call osd volume"))
            hl.bind(mod .. " + T", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && quickshell ipc call osd volume"))
            hl.bind(mod .. " + N", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && quickshell ipc call osd mic"))
            hl.bind(mod .. " + V", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0 && quickshell ipc call osd volume"), { repeating = true })
            hl.bind(mod .. " + C", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0 && quickshell ipc call osd volume"), { repeating = true })
            hl.bind(mod .. " + SHIFT + V", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && quickshell ipc call osd volume"), { repeating = true })

            -- The volume keys have no escape from the limit. The brightness keys
            -- go through the bar's backlight, which holds the 1% floor;
            -- brightnessctl takes only a raw one. On the thinkpad they come from
            -- the Video Bus as taps, so a held key repeats at the firmware's pace.
            local media = { locked = true, repeating = true }
            hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0 && quickshell ipc call osd volume"), media)
            hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && quickshell ipc call osd volume"), media)
            hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && quickshell ipc call osd volume"), media)
            hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && quickshell ipc call osd mic"), media)
            hl.bind("XF86MonBrightnessUp", exec("quickshell ipc call backlight up"), media)
            hl.bind("XF86MonBrightnessDown", exec("quickshell ipc call backlight down"), media)

            hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
            hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
            hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
            hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
            hl.bind(mod .. " + SHIFT + 0", exec("${config.my.quickshell.lockCommand}"), { locked = true })

            -- On release, once the lock has toggled, and passed through, so the
            -- key still reaches the client. Ignoring mods, since the held key's
            -- own Lock is still down on release and would fail an empty mask.
            hl.bind("Caps_Lock", exec("quickshell ipc call osd caps"), {
              release = true,
              non_consuming = true,
              ignore_mods = true,
            })

            -- Apps
            hl.bind(mod .. " + F2", exec("galculator"))
            hl.bind(mod .. " + F4", exec("transmission-gtk"))
            hl.bind(mod .. " + F6", exec("kitty glances"))

            -- A drag or resize dispatcher ends on the button's release by
            -- itself, so these need no mouse option.
            hl.bind(mod .. " + mouse:272", hl.dsp.window.drag())
            hl.bind(mod .. " + mouse:273", hl.dsp.window.resize())
            hl.bind("mouse:275", hl.dsp.window.resize())
            hl.bind("mouse:276", hl.dsp.window.drag())

            hl.define_submap("resize", function()
              for _, step in ipairs({
                { "${dirs.l}", -0.1, 0 },
                { "${dirs.d}", 0, 0.1 },
                { "${dirs.u}", 0, -0.1 },
                { "${dirs.r}", 0.1, 0 },
                { "left", -0.1, 0 },
                { "down", 0, 0.1 },
                { "up", 0, -0.1 },
                { "right", 0.1, 0 },
              }) do
                hl.bind(step[1], grow(step[2], step[3]), { repeating = true })
              end
              -- The bind that enters the submap leaves it too.
              for _, key in ipairs({ "Escape", "Return", mod .. " + R" }) do
                hl.bind(key, hl.dsp.submap("reset"))
              end
            end)
          '';
      };

      # Idle and suspend handling. `lock_cmd` answers logind's Lock signal, and
      # `before_sleep_cmd` raises the lock before the machine suspends so a
      # resume never lands on an unlocked desktop. It first moves the pointer
      # a pixel and back, Hyprland ignoring a move of zero, which restarts the
      # idle timers: a wake is not input, so a step nearly due at the suspend
      # would run the moment the machine wakes.
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = config.my.quickshell.lockCommand;
            # Holds a suspend until Hyprland reports the session locked; the
            # default does so only for a lock_cmd naming hyprlock.
            inhibit_sleep = 3;
            before_sleep_cmd =
              let
                wlrctl = lib.getExe' pkgs.wlrctl "wlrctl";
              in
              "${wlrctl} pointer move 1 0; ${wlrctl} pointer move -1 0; loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
          };
          # One listener per distinct step and threshold. The suspend turns the
          # screen off, and a suspend listener on again, which input alone does
          # not, and ends a suspend step still waiting on a sleep lock; the
          # bracket keeps pkill off the shell running it. Only a dim listener
          # undoes the dim, and only while it is on, so a return from idle
          # without a dim touches nothing.
          listener = unique (
            concatLists (
              mapAttrsToList (
                _:
                mapAttrsToList (
                  step: timeout:
                  {
                    inherit timeout;
                    on-timeout = "${idleStep} ${step} ${toString timeout}";
                  }
                  // optionalAttrs (step == "dim") {
                    on-resume = "hyprctl eval 'if hl.get_config(\"decoration.screen_shader\") ~= \"\" then ${setScreenShader ""} end'";
                  }
                  // optionalAttrs (step == "suspend") {
                    on-resume = "pkill -f '[i]dle-step suspend'; hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
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
        # Forced over the gtk module's, which also sets the theme and icons:
        # `color-scheme` owns those and the color scheme, which a switch must
        # not reset.
        settings."org/gnome/desktop/interface" =
          let
            inherit (config.home-manager.users.${u.name}) gtk;
          in
          mkForce {
            overlay-scrolling = false;
            font-name = "${gtk.font.name} ${toString gtk.font.size}";
            cursor-theme = gtk.cursorTheme.name;
            cursor-size = gtk.cursorTheme.size;
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
        # Desktop is left out: pcmanfm already lists it under Places.
        gtk3.bookmarks =
          with config.home-manager.users.${u.name}.xdg.userDirs;
          map (dir: "file://${dir}") [
            projects
            documents
            download
            pictures
            extraConfig.SCREENSHOTS
            extraConfig.WALLPAPERS
            music
            videos
          ];
        gtk4 = {
          theme = null;
          extraConfig = {
            "gtk-overlay-scrolling" = false;
            "gtk-decoration-layout" = "appmenu:close";
          };
        };
      };
      # The file manager and file chooser write this file too; the declared
      # list wins.
      xdg.configFile."gtk-3.0/bookmarks".force = true;

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        inherit (cursor) package name;
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
          # The Appearance panel's night-light toggle writes `off` here and stops
          # the unit, or empties the file and starts it.
          ConditionFileNotEmpty = "!%S/night-light";
        };
        Service.ExecStart = "${lib.getExe pkgs.wlsunset} -S 07:00 -s 18:30 -T 6500 -t 3500 -d 7200";
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # The wallpaper, which Quickshell's picker sets. The daemon restores each
      # output's last image from its cache, which an awww update empties.
      # Quickshell starts it, once its login curtain covers the screens.
      services.awww.enable = true;
      systemd.user.services.awww.Install.WantedBy = mkForce [ ];
    });
  };
}
