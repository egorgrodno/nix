{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshDir = "${config.home.homeDirectory}/.ssh";
in
{
  home.packages = [ pkgs.openssh ];

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
