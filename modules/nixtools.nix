{ pkgs, username, ... }:

{
  environment.systemPackages = [ pkgs.pciutils ];

  home-manager.users.${username} = {
    home.packages = [
      (pkgs.writeShellScriptBin "nxe" "st -d /etc/nixos -e vim home.nix")
      (pkgs.writeShellScriptBin "nxu" "nix flake update --flake /etc/nixos")
      (pkgs.writeShellScriptBin "nxs" "nixos-rebuild switch --flake /etc/nixos")
      (pkgs.writeShellScriptBin "nxb" "nixos-rebuild build --flake /etc/nixos")
      (pkgs.writeShellScriptBin "nxt" "nixos-rebuild test --flake /etc/nixos")

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

  };
}
