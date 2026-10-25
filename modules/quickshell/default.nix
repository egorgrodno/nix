{
  config,
  lib,
  pkgs,
  forAllUsers,
  theme,
  ...
}:

let
  cfg = config.my.quickshell;

  # The palettes as QML colors, nested names joined in camelCase, so
  # `background.main` reads as `Theme.backgroundMain`. Each takes the light
  # palette's value while `light` holds, which the light palette must define.
  colorProperties =
    let
      camel = lib.concatImapStrings (
        i: s: if i == 1 then s else lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s
      );
    in
    lib.collect lib.isString (
      lib.mapAttrsRecursive (
        path: dark:
        ''readonly property color ${camel path}: light ? "${lib.getAttrFromPath path theme.light}" : "${dark}"''
      ) theme.dark
    );

  # `ColorScheme` is the bar's, which follows the user's file, or the greeter's
  # own, which holds the last user's.
  themeQml = pkgs.writeText "Theme.qml" ''
    pragma Singleton

    import QtQuick
    import Quickshell

    Singleton {
        readonly property bool light: ColorScheme.light
        readonly property string fontMono: "${theme.fontMono}"
        readonly property string fontUI: "${theme.fontUI}"
        ${lib.concatStringsSep "\n    " colorProperties}

        // Also the exclusive zone.
        readonly property int barHeight: ${toString cfg.barHeight}
        // The windows' outer gap, which the segments line up with at the sides.
        readonly property int outerGap: ${toString cfg.outerGap}
        readonly property int radius: 8
        // How far panels and tooltips slide out of the bar as they fade in.
        readonly property int slide: 24
        // How far a panel's or popup's shadow reaches past its box.
        readonly property int shadow: 14

        function alpha(color, a) {
            return Qt.rgba(color.r, color.g, color.b, a);
        }

        // What lifts a fill or a border off the background: white over the
        // dark palette, black over the light one.
        function tint(a) {
            return light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
        }
    }
  '';

  nvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;

  statsProbe = pkgs.writeShellApplication {
    name = "stats-probe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.gnused
      config.systemd.package
    ]
    ++ lib.optional nvidia config.hardware.nvidia.package.bin;
    text = builtins.readFile ./stats-probe.sh;
  };

  # Absolute paths: the bar runs as a systemd user service, whose PATH carries
  # a few core utilities and nothing else.
  programsQml = pkgs.writeText "Programs.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property string awww: "${lib.getExe pkgs.awww}"
        readonly property string bluemanManager: "${lib.getExe' pkgs.blueman "blueman-manager"}"
        readonly property string bosun: "${lib.getExe pkgs.bosun}"
        readonly property string brightnessctl: "${lib.getExe pkgs.brightnessctl}"
        readonly property string cliphist: "${lib.getExe pkgs.cliphist}"
        readonly property string colorScheme: "${config.my.desktop.colorSchemeCommand}"
        readonly property string date: "${lib.getExe' pkgs.coreutils "date"}"
        readonly property string gdbus: "${lib.getExe' pkgs.glib "gdbus"}"
        readonly property string hyprctl: "${lib.getExe' config.programs.hyprland.package "hyprctl"}"
        readonly property string kitty: "${lib.getExe pkgs.kitty}"
        readonly property string loginctl: "${lib.getExe' config.systemd.package "loginctl"}"
        readonly property string lsblk: "${lib.getExe' pkgs.util-linux "lsblk"}"
        readonly property string nmConnectionEditor: "${lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor"}"
        readonly property string nmcli: "${lib.getExe' config.networking.networkmanager.package "nmcli"}"
        readonly property string notifySend: "${lib.getExe' pkgs.libnotify "notify-send"}"
        // Empty without the NVIDIA driver.
        readonly property string nvidiaSmi: "${lib.optionalString nvidia "${config.hardware.nvidia.package.bin}/bin/nvidia-smi"}"
        readonly property string pcmanfm: "${lib.getExe pkgs.pcmanfm}"
        readonly property string ping: "${lib.getExe' pkgs.iputils "ping"}"
        readonly property string pwvucontrol: "${lib.getExe pkgs.pwvucontrol}"
        readonly property string rfkill: "${lib.getExe' pkgs.util-linux "rfkill"}"
        readonly property string rm: "${lib.getExe' pkgs.coreutils "rm"}"
        readonly property string secretTool: "${lib.getExe' pkgs.libsecret "secret-tool"}"
        readonly property string sh: "${pkgs.runtimeShell}"
        readonly property string sleep: "${lib.getExe' pkgs.coreutils "sleep"}"
        readonly property string statsProbe: "${lib.getExe statsProbe}"
        readonly property string systemctl: "${lib.getExe' config.systemd.package "systemctl"}"
        readonly property string systemdInhibit: "${lib.getExe' config.systemd.package "systemd-inhibit"}"
        readonly property string usbFormat: "${lib.getExe (pkgs.callPackage ../../pkgs/usb-format { })}"
        readonly property string uwsm: "${lib.getExe config.programs.uwsm.package}"
        readonly property string wlCopy: "${lib.getExe' pkgs.wl-clipboard "wl-copy"}"
        readonly property string xdgOpen: "${lib.getExe' pkgs.xdg-utils "xdg-open"}"
    }
  '';

  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;

  # Each user's saved monitor layouts, copied by the bar for the greeter.
  sharedLayouts = "/var/lib/monitor-layouts";

  # In the order `Date.getDay()` numbers them.
  weekdays = [
    "sunday"
    "monday"
    "tuesday"
    "wednesday"
    "thursday"
    "friday"
    "saturday"
  ];

  # What the host can do and how it is set up, from its NixOS configuration.
  hostQml = pkgs.writeText "Host.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property bool hibernate: ${lib.boolToString config.base.hibernate}
        readonly property string sharedLayouts: "${sharedLayouts}"
        // As `Date.getDay()` numbers it: 0 is Sunday.
        readonly property int firstDayOfWeek: ${
          toString (lib.lists.findFirstIndex (d: d == cfg.firstDayOfWeek) null weekdays)
        }
        readonly property var worldClocks: ${builtins.toJSON cfg.worldClocks}
    }
  '';

  # The launcher's symbols as [character, name, group]: emoji without their
  # skin-tone variants, then Nerd Fonts' glyphs, whose names should come from
  # the release nixpkgs builds the fonts from.
  symbolsJson =
    let
      glyphNames = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.5.0/glyphnames.json";
        hash = "sha256-CELhoPai49j6f9IrWqtP+Th4JpyMLJFVswfwAOrqD5Q=";
      };
    in
    pkgs.runCommand "symbols.json"
      {
        nativeBuildInputs = [
          pkgs.gawk
          pkgs.jq
        ];
      }
      ''
        {
          awk -F'; fully-qualified +# ' '
            /^# group: / { group = substr($0, 10) }
            NF == 2 && $2 !~ /skin tone/ {
              char = $2; sub(/ .*/, "", char)
              name = $2; sub(/^[^ ]+ E[0-9.]+ /, "", name)
              print char "\t" name "\t" group
            }' ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt
          jq -r 'del(.METADATA) | to_entries[] | [.value.char, .key, "Nerd Font"] | @tsv' ${glyphNames}
        } | jq -R -s -c 'split("\n") | map(select(. != "") | split("\t"))' > $out
      '';

  # The disk tooltip's drive health, which takes root to read: each drive's
  # smartctl report in /run/drive-health/<drive>.json. A report without a
  # verdict, as from a drive asleep, keeps the last one.
  driveHealth = pkgs.writeShellApplication {
    name = "drive-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.smartmontools
      pkgs.util-linux
    ];
    text = ''
      cd /run/drive-health
      lsblk --nodeps --noheadings --output NAME,TYPE | while read -r name type; do
        case $type:$name in disk:zram* | disk:loop*) continue ;; disk:*) ;; *) continue ;; esac
        smartctl --json=c --all --nocheck=standby "/dev/$name" >"$name.json.new" || :
        if grep -q '"smart_status"' "$name.json.new"; then
          mv "$name.json.new" "$name.json"
        else
          rm "$name.json.new"
        fi
      done
    '';
  };

  # The flag first, which a bar starting under it locks on, so a lock asked for
  # while the bar is down still happens once it is back.
  lockCommand = pkgs.writeShellScript "lock" ''
    printf %s "$HYPRLAND_INSTANCE_SIGNATURE" >"$XDG_RUNTIME_DIR/quickshell-lock"
    ${lib.getExe pkgs.quickshell} ipc call lock lock ||
      ${lib.getExe' config.systemd.package "systemctl"} --user start quickshell.service
  '';

  # The greeter's users and sessions: the normal users, and each
  # wayland-sessions entry's name, command and desktop names, which tuigreet
  # also passed on as XDG_CURRENT_DESKTOP.
  loginsJson =
    pkgs.runCommand "logins.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        users = builtins.toJSON (lib.mapAttrsToList (name: _: { inherit name; }) normalUsers);
        defaultSession = toString config.services.displayManager.defaultSession;
      }
      ''
        for f in ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/*.desktop; do
          key() { sed -n "s/^$1=//p" "$f" | head -n 1; }
          jq -n --arg slug "$(basename "$f" .desktop)" --arg name "$(key Name)" \
            --arg exec "$(key Exec)" --arg desktops "$(key DesktopNames)" \
            '{ $slug, $name, $exec, desktops: ($desktops | split(";") | map(select(. != "")) | join(":")) }'
        done | jq -s --argjson users "$users" --arg default "$defaultSession" \
          '{ $users, sessions: ., defaultSession: $default }' >$out
      '';

  # Its own config directory, with the files it shares with the bar.
  greeterConfig = pkgs.runCommand "quickshell-greeter" { } ''
    mkdir $out
    cp ${./greeter}/*.qml $out/
    ${lib.concatMapStrings (f: "cp ${./. + "/${f}"} $out/${f}\n") [
      "BarText.qml"
      "BigClock.qml"
      "CapsLock.qml"
      "Figure.qml"
      "KeyBuffer.qml"
      "LoginCard.qml"
      "Monitors.qml"
      "PasswordField.qml"
      "SharedLayouts.qml"
    ]}
    cp ${themeQml} $out/Theme.qml
    cp ${hostQml} $out/Host.qml
    cp ${programsQml} $out/Programs.qml
    cp ${loginsJson} $out/logins.json
  '';

  # One link per file rather than one for the directory, so dev mode can swap
  # each for a writable copy.
  configFiles =
    lib.mapAttrs' (name: _: lib.nameValuePair "quickshell/${name}" { source = ./. + "/${name}"; }) (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".qml" name) (builtins.readDir ./.)
    )
    // {
      "quickshell/Theme.qml".source = themeQml;
      "quickshell/Programs.qml".source = programsQml;
      "quickshell/Host.qml".source = hostQml;
      "quickshell/symbols.json".source = symbolsJson;
    };

in
{
  options.my.quickshell = {
    enable = lib.mkEnableOption "Quickshell bar";

    barHeight = lib.mkOption {
      type = lib.types.int;
      description = "Height of each bar, top and bottom, in logical pixels, which it also reserves as its exclusive zone.";
    };

    outerGap = lib.mkOption {
      type = lib.types.int;
      description = "Hyprland's outer gap in logical pixels, which the bars' segments line up with at the sides.";
    };

    firstDayOfWeek = lib.mkOption {
      type = lib.types.enum weekdays;
      description = "Day each week starts on in the bar's calendar.";
    };

    worldClocks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "Europe/Minsk" ];
      description = "Time zones whose time the bar's calendar shows, each named after its city.";
    };

    lockCommand = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${lockCommand}";
      description = "Command that locks the session through the bar's lock screen, starting the bar should it be down.";
    };

    greeter = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = greeterConfig;
      description = "Quickshell config directory of the greetd greeter, which runs inside a Hyprland of its own.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.pam.services.quickshell-lock = { };

    systemd.services.drive-health = {
      description = "SMART report of each drive for the bar";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe driveHealth;
        RuntimeDirectory = "drive-health";
        RuntimeDirectoryPreserve = true;
      };
    };
    systemd.timers.drive-health = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1h";
      };
    };

    # A failing drive notifies the session without a hover over the module.
    services.smartd = {
      enable = true;
      notifications.systembus-notify.enable = true;
    };

    # The directory root's and each file its user's, so a user writes only their
    # own layouts and the greeter reads them all.
    systemd.tmpfiles.settings.monitor-layouts = {
      ${sharedLayouts}.d.mode = "0755";
    }
    // lib.mapAttrs' (
      name: u:
      lib.nameValuePair "${sharedLayouts}/${name}.json" {
        f = {
          user = name;
          inherit (u) group;
          mode = "0644";
        };
      }
    ) normalUsers;

    home-manager.users = forAllUsers {
      programs.quickshell = {
        enable = true;
        systemd.enable = true;
      };

      xdg.configFile = configFiles;

      # The panels without a module, from the launcher as from their binds.
      xdg.desktopEntries.displays = {
        name = "Displays";
        genericName = "Monitor layout";
        exec = "${lib.getExe pkgs.quickshell} ipc call monitors toggle";
        icon = "preferences-desktop-display";
        categories = [ "Settings" ];
      };
      xdg.desktopEntries.appearance = {
        name = "Appearance";
        genericName = "Wallpaper, light and dark mode";
        exec = "${lib.getExe pkgs.quickshell} ipc call wallpapers toggle";
        icon = "preferences-desktop-wallpaper";
        categories = [ "Settings" ];
        settings.Keywords = "wallpaper;background;theme;light;dark;night light;";
      };
      xdg.desktopEntries.format-usb = {
        name = "Format USB Drive";
        genericName = "Erase a USB stick as FAT32, exFAT, NTFS or ext4";
        exec = "${lib.getExe pkgs.quickshell} ipc call format toggle";
        icon = "drive-removable-media-usb";
        categories = [ "System" ];
        settings.Keywords = "format;erase;wipe;usb;stick;flash;drive;fat32;exfat;ntfs;ext4;";
      };

      # Quickshell is the notification daemon: a notification sent while the
      # bar is down starts it rather than failing.
      xdg.dataFile."dbus-1/services/org.freedesktop.Notifications.service".text = ''
        [D-BUS Service]
        Name=org.freedesktop.Notifications
        Exec=${lib.getExe' pkgs.coreutils "false"}
        SystemdService=quickshell.service
      '';

      # Tray applets order after tray.target, which pulls the bar in. Without
      # `ConditionEnvironment` the bar starts against a missing compositor and
      # burns through the start limit.
      systemd.user.services.quickshell = {
        Unit = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
          PartOf = [
            "graphical-session.target"
            "tray.target"
          ];
          X-Restart-Triggers = lib.mapAttrsToList (_: f: "${f.source}") configFiles;
        };
        # GTK's palette, font and icon theme, so tray icons and their menus
        # match the GTK applications.
        Service.Environment = [ "QT_QPA_PLATFORMTHEME=gtk3" ];
        Install.WantedBy = [ "tray.target" ];
      };
    };
  };
}
