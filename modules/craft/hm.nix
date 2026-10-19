{ pkgs, lib, ... }:

{
  home.packages =
    lib.mapAttrsToList (name: src: pkgs.callPackage ./package.nix ({ inherit name; } // src)) (
      lib.importJSON ./sources.json
    )
    ++ [ (pkgs.callPackage ../../pkgs/craft-update { }) ];
}
