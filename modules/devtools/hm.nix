{
  config,
  lib,
  pkgs,
  isDesktop,
  ...
}:

with pkgs;

let
  sshDir = "${config.home.homeDirectory}/.ssh";
  desktopPackages = [
    (writeShellScriptBin "chromium-without-cors" ''
      chromium --disable-web-security --user-data-dir=.config/chromium-without-cors
    '')
  ];
in
{
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
  ]
  ++ (if isDesktop then desktopPackages else [ ]);

  # Hosts stay out of the flake: ~/.ssh/config.local is untracked, and ssh skips
  # an Include that matches no file.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "config.local" ];
  };

  # A copy, not a store symlink: in the Claude Code sandbox's user namespace the
  # store's root owner shows as nobody, and ssh refuses a config it doesn't own.
  home.file.".ssh/config".enable = false;
  home.activation.sshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -d -m 700 ${sshDir}
    run install -m 600 ${config.home.file.".ssh/config".source} ${sshDir}/config
  '';
}
