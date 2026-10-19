{
  writeShellApplication,
  curl,
  jq,
}:

writeShellApplication {
  name = "craft-update";
  runtimeInputs = [
    curl
    jq
  ];
  text = builtins.readFile ./craft-update.sh;
}
