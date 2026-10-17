{ pkgs, ... }:

{
  home.packages = [
    # Wraps `nix run`, so it only works where Nix is available.
    (pkgs.writeShellScriptBin "claude" ''
      nix run github:sadjow/claude-code-nix -- "$@"
    '')

    # Statusline for the Claude Code CLI: ccusage's session/context readout.
    (pkgs.writeShellScriptBin "claude-statusline" ''
      exec npx ccusage@latest statusline --context-low-threshold 50 --context-medium-threshold 85
    '')
  ];
}
