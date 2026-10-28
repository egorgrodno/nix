#!/usr/bin/env bash
# Walks the panel's sizes and states: the full panel with the sidebar open and
# collapsed to the rail, the Log beside each, the overview, Waiting on you at
# 0, and a fleet that outgrows the rail. Checks the full panel's box against
# the work area grown by the window border, and the buttons that switch the
# sidebar and the size. With -o DIR, takes a PNG of each state.
set -euo pipefail
# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

shot() {
  [[ -n ${SNAPS:-} ]] || return 0
  sleep 0.8
  "$GRIM" "$SNAPS/$1.png"
}

# Whatever an earlier script left, and back to the fleet it found.
trap 'qs call harness fleet 0 >/dev/null 2>&1 || true; qs call harness decide 7 select-lag >/dev/null 2>&1 || true' EXIT
closed

call open
await entered true
call mode full >/dev/null
call sidebar open >/dev/null

# The box covers the window border: the work area, the screen less the outer
# gap and both bars, grown 2 px each side.
geo=$(call geometry)
echo "geometry full: $geo"
expect "full x" 8 "$(jq .x <<<"$geo")"
expect "full y" 57 "$(jq .y <<<"$geo")"
screen=$(qs call harness screenSize)
expect "full width" $((${screen%x*} - 16)) "$(jq .width <<<"$geo")"
expect "full height" $((${screen#*x} - 114)) "$(jq .height <<<"$geo")"

call select desk >/dev/null
shot a-desk-sidebar

call sidebar closed >/dev/null
call select session:select-lag >/dev/null
await focus rail
shot b-worker-rail

call sidebar open >/dev/null
call select log >/dev/null
shot c-log-sidebar
call sidebar closed >/dev/null
shot d-log-rail

call select desk >/dev/null

# The title bar's buttons: the toggle at its far left, and the overview's at
# its far right, whose own button at its top right switches back. labwc never
# gives the panel its keyboard, so the keys are scenarios/keys.qml's.
open=$(field sidebarOpen)
click 34 83
[[ $(field sidebarOpen) != "$open" ]] || fail "the toggle left the sidebar as it was"
click 34 83
expect "the toggle twice" "$open" "$(field sidebarOpen)"
click 1396 83
await mode overview
geo=$(call geometry)
shot e-overview
click $(($(jq '.x + .width' <<<"$geo") - 32)) $(($(jq .y <<<"$geo") + 32))
await mode full
echo "the toggle switched the sidebar and the buttons the size"

# Nothing waits: the sidebar's faint line and the rail's inert tile.
qs call harness settle 7 >/dev/null
call sidebar open >/dev/null
call select desk >/dev/null
shot f-none-sidebar
call sidebar closed >/dev/null
shot f-none-rail
point 46 139
shot f-none-rail-hover
call mode overview >/dev/null
shot f-none-overview
call mode full >/dev/null

# Three decisions wait, and a fleet that outgrows the rail.
qs call harness decide 7 select-lag >/dev/null
qs call harness decide 8 panel-ipc >/dev/null
qs call harness decide 9 worker-3 >/dev/null
qs call harness decide 10 worker-5 >/dev/null
qs call harness fleet 30 >/dev/null
shot g-fleet-rail
call select session:worker-30 >/dev/null
shot g-fleet-rail-end
call mode overview >/dev/null
shot g-fleet-overview
call mode full >/dev/null
call sidebar open >/dev/null
qs call harness settle 8 >/dev/null
qs call harness settle 9 >/dev/null
qs call harness settle 10 >/dev/null

closed
echo "sizes walked"
