#!/usr/bin/env bash
# Opens the Log page's session menu and checks that a press anywhere in the
# panel closes it, and goes no further. $WLRCTL moves the harness
# compositor's own pointer, never the live one.
set -euo pipefail

qs() { "$QS" ipc --path "$QS_CONFIG" "$@"; }
call() { qs call bosun "$@"; }
field() { call state | jq -r ".$1"; }

fail() {
  echo "FAIL: $*"
  exit 1
}

# Moves the pointer to the output's x, y: to the corner, then across.
point() {
  "$WLRCTL" pointer move -4000 -4000
  "$WLRCTL" pointer move "$1" "$2"
}

click() {
  point "$1" "$2"
  "$WLRCTL" pointer click left
  sleep 0.5
}

shot() { [[ -z ${SNAPS:-} ]] || "$GRIM" "$SNAPS/$1.png"; }

# From a closed panel, whatever an earlier script left.
call close
for _ in $(seq 25); do
  [[ $(qs call harness panels) == 0 ]] && break
  sleep 0.2
done
call open
for _ in $(seq 25); do
  [[ $(field entered) == true ]] && break
  sleep 0.2
done
call mode expanded
call select log
sleep 1
shot log-closed

# The filter's button in the expanded panel, and places to press outside the
# menu: the rail, the table, the detail pane and the header.
button="762 181"
outside=("38 189" "300 480" "1000 450" "300 85")

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
click $button
click 740 268
[[ $(field focus) == "$home" ]] || fail "a pick left the menu open, focus is $(field focus)"
shot log-picked
echo "a pick closed the menu"
