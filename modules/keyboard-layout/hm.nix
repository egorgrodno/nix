{ pkgs, ... }:

{
  home.packages = [ (pkgs.callPackage ../../pkgs/kb-layout { }) ];
}
