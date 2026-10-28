{
  bosunSleepLock,
  bosunSleepLockQuiet,
  keyboardLayout,
  lib,
  pkgs,
  ...
}:

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

  # `bosun tui` moves by this layout's direction keys.
  home.sessionVariables.BOSUN_LAYOUT = keyboardLayout;

  systemd.user.services.bosun = {
    Unit = {
      Description = "bosun daemon, which runs a master Claude Code session over its workers";
      # The master's directory needs Claude Code's trust before the first start,
      # so an account starts no daemon until nx-setup makes the directory and
      # trusts it.
      ConditionPathExists = "%S/bosun/master";
      # Every background session, the user's own included, takes the
      # environment of the supervisor this starts, so it waits for uwsm to copy
      # the session's environment into systemd.
      After = [ "graphical-session.target" ];
    };
    Service = {
      # The sleep lock runs `systemd-inhibit` and `sleep` from the unit's PATH,
      # which is the session's, so it must not be overridden here: every
      # background session inherits it.
      ExecStart = "${lib.getExe pkgs.bosun} daemon -max-depth 10 -max-children 20 -sleep-lock ${bosunSleepLock} -sleep-lock-quiet ${bosunSleepLockQuiet}";
      # Every background session runs in the cgroup of the first `claude --bg`,
      # usually this unit's, so the default would stop them all with the daemon.
      # The sleep lock's inhibitor is killed by Pdeathsig instead, so a crashed
      # daemon does not leave it holding the lock.
      KillMode = "process";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
