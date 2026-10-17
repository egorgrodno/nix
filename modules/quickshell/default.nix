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
        readonly property int radius: 8

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
        readonly property string notifySend: "${lib.getExe' pkgs.libnotify "notify-send"}"
        readonly property string pcmanfm: "${lib.getExe pkgs.pcmanfm}"
        readonly property string pwvucontrol: "${lib.getExe pkgs.pwvucontrol}"
        readonly property string rfkill: "${lib.getExe' pkgs.util-linux "rfkill"}"
        readonly property string systemctl: "${lib.getExe' config.systemd.package "systemctl"}"
        readonly property string wlogout: "${lib.getExe pkgs.wlogout}"
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
      description = "Height of the bar in logical pixels, which it also reserves as its exclusive zone.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users = forAllUsers {
      programs.quickshell = {
        enable = true;
        systemd.enable = true;
      };

      xdg.configFile = configFiles;

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
