{
  writeShellApplication,
  coreutils,
  e2fsprogs,
  efibootmgr,
  nixos-enter,
  util-linux,
}:

writeShellApplication {
  name = "repair-boot";
  runtimeInputs = [
    coreutils
    e2fsprogs
    efibootmgr
    nixos-enter
    util-linux
  ];
  text = builtins.readFile ./repair-boot.sh;
}
