{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "claude-statusline" ''
      input=$(cat)
      effort=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.effort.level // ""')
      result=$(printf '%s' "$input" | npx ccusage@latest statusline --context-low-threshold 50 --context-medium-threshold 85)
      [ -n "$effort" ] && echo "$effort | $result" || echo "$result"
    '')
    (pkgs.writeShellScriptBin "nxu" "nix flake update --flake /etc/nixos")
    (pkgs.writeShellScriptBin "nxs" "nixos-rebuild switch --flake /etc/nixos#fractal-wayland")
    (pkgs.writeShellScriptBin "nxc" "nixos-rebuild build --flake /etc/nixos#fractal-wayland")
    (pkgs.writeShellScriptBin "nxb" "nixos-rebuild boot --flake /etc/nixos#fractal-wayland")
    (pkgs.writeShellScriptBin "nxt" "nixos-rebuild test --flake /etc/nixos#fractal-wayland")

    (pkgs.writeShellScriptBin "permfixer" ''
      if [ -z "$1" ]; then
        echo "Usage: $(basename $0) path"
        exit 1
      fi

      target_path="$1"

      # Check if the path exists
      if [ ! -e "$target_path" ]; then
        echo "Error: path does not exist"
        exit 1
      fi

      echo "setting 755 permissions for directories"
      find "$target_path" -type d -exec chmod 755 {} +

      echo "setting 644 permissions for files"
      find "$target_path" -type f -exec chmod 644 {} +
    '')
  ];
}
