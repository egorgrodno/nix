{
  writeShellApplication,
  coreutils,
  efibootmgr,
  nixos-enter,
  util-linux,
}:

writeShellApplication {
  name = "repair-boot";
  runtimeInputs = [
    coreutils
    efibootmgr
    nixos-enter
    util-linux
  ];
  text = builtins.readFile ./repair-boot.sh;
}
