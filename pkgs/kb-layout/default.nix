{
  writeShellApplication,
  coreutils,
}:

writeShellApplication {
  name = "kb-layout";
  runtimeInputs = [ coreutils ];
  text = builtins.readFile ./kb-layout.sh;
}
