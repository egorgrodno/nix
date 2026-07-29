# Translucent form of a `theme` color, for the GTK stylesheets.
#
# GTK CSS cannot add an alpha channel to a hex literal, and a hand-written
# `rgba(...)` is drift waiting to happen: it keeps the old color silently when
# the theme moves. Applied as `import ../../lib/rgba.nix lib theme.red "0.5"`.
lib: hex: alpha:
let
  s = lib.toLower (lib.removePrefix "#" hex);
  digits = "0123456789abcdef";
  value = c: lib.stringLength (lib.head (lib.splitString c digits));
  byte = i: value (lib.substring i 1 s) * 16 + value (lib.substring (i + 1) 1 s);
in
"rgba(${toString (byte 0)}, ${toString (byte 2)}, ${toString (byte 4)}, ${alpha})"
