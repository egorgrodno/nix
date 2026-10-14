{
  writeShellApplication,
  coreutils,
  gh,
  git,
  gnused,
  gum,
  jq,
  openssh,
  tea,
}:

writeShellApplication {
  name = "nx-setup";
  # No neovim: the user's configured wrapper comes from PATH.
  runtimeInputs = [
    coreutils
    gh
    git
    gnused
    gum
    jq
    openssh
    tea
  ];
  # `step` calls each step function through a variable, which shellcheck cannot follow.
  excludeShellChecks = [ "SC2329" ];
  text = builtins.readFile ./nx-setup.sh;
}
