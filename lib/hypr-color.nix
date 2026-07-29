# Hyprland's color literal for a `theme` color.
#
# Hyprland and hyprlock do not take CSS syntax: they want `rgba(RRGGBBAA)` —
# eight hex digits, no separators and no leading `#` — so `rgba.nix` does not
# apply here. Alpha is given as the two hex digits Hyprland's own configuration
# uses, so `ff` is opaque. Applied as
# `import ../../lib/hypr-color.nix lib theme.blue "ff"`.
lib: hex: alpha:
"rgba(${lib.toLower (lib.removePrefix "#" hex)}${alpha})"
