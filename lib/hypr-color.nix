# Hyprland's color literal for a `theme` color: `rgba(RRGGBBAA)`, eight hex
# digits with no separators and no leading `#`. Not CSS, and alpha is two hex
# digits — `ff` is opaque.
lib: hex: alpha:
"rgba(${lib.toLower (lib.removePrefix "#" hex)}${alpha})"
