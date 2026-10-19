{ pkgs, lib, ... }:

let
  apps = lib.mapAttrsToList (name: src: pkgs.callPackage ./package.nix ({ inherit name; } // src)) (
    lib.importJSON ./sources.json
  );
in
{
  home.packages = apps ++ [ (pkgs.callPackage ../../pkgs/craft-update { }) ];

  # The tarballs are only build inputs, which garbage collection takes; kept,
  # rebuilding the pinned versions needs no GitHub.
  home.extraDependencies = map (app: app.src) apps;
}
