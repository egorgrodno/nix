#!/usr/bin/env bash
# Opens the Log page's session menu and checks that a press anywhere in the
# panel closes it, and goes no further. $WLRCTL moves the harness
# compositor's own pointer, never the live one.
set -euo pipefail
# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

shot() { [[ -z ${SNAPS:-} ]] || "$GRIM" "$SNAPS/$1.png"; }

# From a closed panel, whatever an earlier script left.
closed
call open
await entered true
call mode full
call sidebar closed
call select log
sleep 1
shot log-closed

# The filter's button beside the rail, and places to press outside the menu:
# the rail, the table, the detail pane and the header.
button="525 179"
outside=("46 650" "500 480" "1200 450" "700 83")

selected=$(field selected)
[[ $selected == log:* ]] || fail "select log kept $selected"

home=$(field focus)
for place in "${outside[@]}"; do
  # shellcheck disable=SC2086
  click $button
  [[ $(field focus) == field ]] || fail "the menu did not open, focus is $(field focus)"
  shot log-open
  # shellcheck disable=SC2086
  click $place
  [[ $(field focus) == "$home" ]] || fail "a press at $place left the menu open, focus is $(field focus)"
  [[ $(field selected) == "$selected" ]] || fail "a press at $place reached what is under it: $(field selected)"
  echo "a press at $place closed the menu and went no further"
done

# A click on a session picks it and closes the menu.
# shellcheck disable=SC2086
click $button
click 503 266
[[ $(field focus) == "$home" ]] || fail "a pick left the menu open, focus is $(field focus)"
shot log-picked
echo "a pick closed the menu"
