{
  lib,
  pkgs,
  forAllUsers,
  ...
}:

{
  home-manager.users = forAllUsers {
    home.packages = with pkgs; [
      nextcloud-client
    ];

    # `BindsTo` pulls graphical-session.target in, so a `WantedBy` of
    # default.target activates that target at login, before the compositor
    # exists, leaving everything else that waits on it with no WAYLAND_DISPLAY.
    # `PartOf` only follows the target down.
    systemd.user.services.nextcloud-sync = {
      Unit = {
        Description = "Nextcloud Client Sync";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.nextcloud-client} --logfile /tmp/nextcloud-sync.log";
        Restart = "on-failure";
        KillMode = "process";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    # The client writes this entry itself whenever "Launch on system startup" is
    # ticked, and a uwsm session honours XDG autostart, so it raises a second
    # tray icon beside the unit above. `Hidden` retires an entry, and owning the
    # file keeps the client from reinstating it.
    xdg.configFile."autostart/Nextcloud.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Nextcloud
      Hidden=true
    '';
  };
}
