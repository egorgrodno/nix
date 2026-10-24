{
  lib,
  xdg-utils,
  glib,
  symlinkJoin,
  writeShellApplication,
}:

# Outside the desktops it recognises, xdg-open looks up a type's default without
# following MIME aliases or parent types, so a `.nix` or `.mkv` file opens in
# the browser. `gio open` follows both.
let
  xdg-open = writeShellApplication {
    name = "xdg-open";
    text = ''exec ${lib.getExe' glib "gio"} open "$@"'';
  };
in
# First in `paths`, so its xdg-open shadows xdg-utils'.
symlinkJoin {
  name = "xdg-utils-${xdg-utils.version}";
  paths = [
    xdg-open
    xdg-utils
  ];
  inherit (xdg-utils) meta;
}
