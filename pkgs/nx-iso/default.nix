{
  writeShellApplication,
  coreutils,
  gnugrep,
}:

writeShellApplication {
  name = "nx-iso";
  # No nix: the host's own.
  runtimeInputs = [
    coreutils
    gnugrep
  ];
  text = builtins.readFile ./nx-iso.sh;
}
