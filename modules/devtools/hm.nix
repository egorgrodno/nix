{ pkgs, isDesktop, ... }:

with pkgs;

let
  desktopPackages = [
    (writeShellScriptBin "chromium-without-cors" ''
      chromium --disable-web-security --user-data-dir=.config/chromium-without-cors
    '')
  ];
in {
  home.packages = [
    fd
    jq
    nodejs
    gcc
    openssh
    xclip

    (writeShellScriptBin "showsrc" "cat $(which $1)")

    (writeShellScriptBin "docker-clean" ''
      set -euo pipefail

      # Auto-elevate only when the socket is not reachable as the current user.
      DOCKER="docker"
      $DOCKER info >/dev/null 2>&1 || DOCKER="sudo docker"

      # Force-remove every container, running or stopped. Empty-safe: docker rm
      # errors out when the id list expands to nothing.
      ids="$($DOCKER ps -aq)"
      if [ -n "$ids" ]; then
        # shellcheck disable=SC2086  # word splitting is the point
        $DOCKER rm -vf $ids
      fi

      # Removing the containers first makes every image count as unused, so -a
      # sweeps all images plus all build cache; --volumes adds unused volumes.
      $DOCKER system prune -af --volumes
    '')
  ] ++ (if isDesktop then desktopPackages else []);
}
