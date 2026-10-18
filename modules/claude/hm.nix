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
  ];
}
