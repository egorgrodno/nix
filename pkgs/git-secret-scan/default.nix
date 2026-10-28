{
  writeShellApplication,
  writeText,
  git,
  gitleaks,
}:

writeShellApplication {
  name = "git-secret-scan";
  runtimeInputs = [
    git
    gitleaks
  ];
  runtimeEnv.DEFAULT_CONFIG = writeText "gitleaks.toml" ''
    [extend]
    useDefault = true
  '';
  text = builtins.readFile ./git-secret-scan.sh;
}
