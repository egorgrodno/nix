{
  writeShellApplication,
  callPackage,
  coreutils,
  diffutils,
  findutils,
  gum,
  jq,
  util-linux,
}:

writeShellApplication {
  name = "nx-flash";
  runtimeInputs = [
    (callPackage ../nx-iso { })
    coreutils
    diffutils
    findutils
    gum
    jq
    util-linux
  ];
  text = builtins.readFile ./nx-flash.sh;
}
