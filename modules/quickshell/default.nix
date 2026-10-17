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

  # `theme` as QML properties, nested names joined in camelCase, so
  # `background.main` reads as `Theme.backgroundMain`. A hex value is a color.
  themeProperties =
    let
      join =
        prefix: name:
        if prefix == "" then
          name
        else
          prefix + lib.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;
      flatten =
        prefix: attrs:
        lib.concatLists (
          lib.mapAttrsToList (
            name: value:
            if lib.isAttrs value then
              flatten (join prefix name) value
            else
              [ (lib.nameValuePair (join prefix name) value) ]
          ) attrs
        );
    in
    map (
      p:
      ''readonly property ${
        if lib.hasPrefix "#" p.value then "color" else "string"
      } ${p.name}: "${p.value}"''
    ) (flatten "" theme);

  themeQml = pkgs.writeText "Theme.qml" ''
    pragma Singleton

    import QtQuick
    import Quickshell

    Singleton {
        ${lib.concatStringsSep "\n    " themeProperties}

        // Also the exclusive zone.
        readonly property int barHeight: ${toString cfg.barHeight}
        // The windows' outer gap, which the segments line up with at the sides.
        readonly property int outerGap: ${toString cfg.outerGap}
        readonly property int radius: 8
        // How far panels and tooltips slide out of the bar as they fade in.
        readonly property int slide: 24

        function alpha(color, a) {
            return Qt.rgba(color.r, color.g, color.b, a);
        }
    }
  '';

  # Absolute paths: the bar runs as a systemd user service, whose PATH carries
  # a few core utilities and nothing else.
  programsQml = pkgs.writeText "Programs.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property string bluemanManager: "${lib.getExe' pkgs.blueman "blueman-manager"}"
        readonly property string brightnessctl: "${lib.getExe pkgs.brightnessctl}"
        readonly property string df: "${lib.getExe' pkgs.coreutils "df"}"
        readonly property string nmConnectionEditor: "${lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor"}"
        readonly property string nmcli: "${lib.getExe' config.networking.networkmanager.package "nmcli"}"
        readonly property string notifySend: "${lib.getExe' pkgs.libnotify "notify-send"}"
        readonly property string pcmanfm: "${lib.getExe pkgs.pcmanfm}"
        readonly property string pwvucontrol: "${lib.getExe pkgs.pwvucontrol}"
        readonly property string rfkill: "${lib.getExe' pkgs.util-linux "rfkill"}"
        readonly property string systemctl: "${lib.getExe' config.systemd.package "systemctl"}"
        readonly property string wlogout: "${lib.getExe pkgs.wlogout}"
        readonly property string xdgOpen: "${lib.getExe' pkgs.xdg-utils "xdg-open"}"
    }
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
  };

  config = lib.mkIf cfg.enable {
    home-manager.users = forAllUsers {
      programs.quickshell = {
        enable = true;
        systemd.enable = true;
      };

      xdg.configFile = configFiles;

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
