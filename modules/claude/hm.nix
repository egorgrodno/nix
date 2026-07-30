{ pkgs, ... }:

{
  home.packages = [
    # Wraps `nix run`, so it only works where Nix is available.
    (pkgs.writeShellScriptBin "claude" ''
      nix run github:sadjow/claude-code-nix -- "$@"
    '')

    # Statusline for the Claude Code CLI: prepends the current effort level to
    # ccusage's session/context readout.
    (pkgs.writeShellScriptBin "claude-statusline" ''
      input=$(cat)
      effort=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.effort.level // ""')
      result=$(printf '%s' "$input" | npx ccusage@latest statusline --context-low-threshold 50 --context-medium-threshold 85)
      [ -n "$effort" ] && echo "$effort | $result" || echo "$result"
    '')
  ];
}
