{
  writeShellApplication,
  coreutils,
  dosfstools,
  e2fsprogs,
  findutils,
  gawk,
  git,
  gnugrep,
  gnused,
  gptfdisk,
  gum,
  jq,
  nixfmt,
  nixos-install-tools,
  pciutils,
  systemd,
  util-linux,
}:

writeShellApplication {
  name = "install";
  # No nix: the ISO's own, which nixos-install also calls, so one version
  # writes its store.
  runtimeInputs = [
    coreutils
    dosfstools
    e2fsprogs
    findutils
    gawk
    git
    gnugrep
    gnused
    gptfdisk
    gum
    jq
    nixfmt
    nixos-install-tools
    pciutils
    systemd
    util-linux
  ];
  text = builtins.readFile ./install.sh;
}
