{ pkgs, username, ... }:

{
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      nextcloud-client
    ];

    systemd.user.services.nextcloud-sync = {
      Unit = {
        Description = "Nextcloud Client Sync";
        After = [ "graphical-session.target" ]; 
        BindsTo = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.nextcloud-client}/bin/nextcloud --logfile /tmp/nextcloud-sync.log";
        Restart = "on-failure"; 
        KillMode = "process";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
