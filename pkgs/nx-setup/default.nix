{
  writeShellApplication,
  coreutils,
  gh,
  git,
  gnused,
  gum,
  jq,
  libsecret,
  openssh,
  tea,
}:

writeShellApplication {
  name = "nx-setup";
  # No neovim or kb-layout: both come from the user's PATH, neovim as its
  # configured wrapper.
  runtimeInputs = [
    coreutils
    gh
    git
    gnused
    gum
    jq
    libsecret
    openssh
    tea
  ];
  # `step` calls each step function through a variable, which shellcheck cannot follow.
  excludeShellChecks = [ "SC2329" ];
  text = builtins.readFile ./nx-setup.sh;
}
