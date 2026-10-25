{ lib, pkgs, ... }:

{
  home.packages = [
    # Wraps `nix run`, so it only works where Nix is available.
    (pkgs.writeShellScriptBin "claude" ''
      nix run github:sadjow/claude-code-nix -- "$@"
    '')

    # Statusline for the Claude Code CLI: ccusage's session/context readout.
    # Online pricing: the bundled table lags new models, which then read $0.00
    # against a 200k context window.
    (pkgs.writeShellScriptBin "claude-statusline" ''
      exec ${lib.getExe pkgs.ccusage} statusline --no-offline --context-low-threshold 50 --context-medium-threshold 85
    '')

    pkgs.bosun
  ];

  systemd.user.services.bosun = {
    Unit = {
      Description = "bosun daemon, which runs a master Claude Code session over its workers";
      # The master's directory needs Claude Code's trust before the first start,
      # so an account starts no daemon until it makes the directory and runs
      # `claude` there once.
      ConditionPathExists = "%S/bosun/master";
      # Every background session, the user's own included, takes the
      # environment of the supervisor this starts, so it waits for uwsm to copy
      # the session's environment into systemd.
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.bosun} daemon";
      # Every background session runs in the cgroup of the first `claude --bg`,
      # usually this unit's, so the default would stop them all with the daemon.
      KillMode = "process";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
