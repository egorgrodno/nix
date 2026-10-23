{
  lib,
  gum,
  makeBinaryWrapper,
  symlinkJoin,
}:

# `--set-default`, so a caller's own GUM_* variable still wins, as a flag does.
symlinkJoin {
  name = "gum-${gum.version}";
  paths = [ gum ];
  nativeBuildInputs = [ makeBinaryWrapper ];
  postBuild = ''
    wrapProgram $out/bin/gum ${
      lib.concatStringsSep " " (
        lib.mapAttrsToList (name: value: "--set-default ${name} ${lib.escapeShellArg value}") (
          import ../../lib/gum-theme.nix
        )
      )
    }
  '';
  inherit (gum) meta;
}
