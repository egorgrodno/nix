#!/usr/bin/env bash
# Takes a PNG of each pane of the full panel into $SNAPS, for comparing looks
# between revisions. $GRIM captures the harness compositor's own screen.
set -euo pipefail

[[ -n ${SNAPS:-} ]] || {
  echo "views: no -o DIR to write the PNGs to"
  exit 0
}

# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Lets the panel settle, then captures it as $1.
shot() {
  sleep 1
  "$GRIM" "$SNAPS/$1.png"
}

# A failure between the two calls must not leave the banners for the next script.
trap 'qs call harness banners false >/dev/null 2>&1 || true' EXIT

call open
await entered true
call mode full
call sidebar closed

# log:32 and log:33 are the escalated and the settled entry of decision 7.
for row in decision:7 desk session:select-lag session:panel-ipc log:32 log:33 log; do
  call select "$row" >/dev/null
  shot "${row%%:*}-${row##*:}"
done

# One Log entry of each kind the daemon logs, as the table and the pane show it.
for kind in allowed parked stalled away back granted revoked expired sleeplock message resumed killed paused unpaused model turn_end exit say interrupt compact clear prompt; do
  call select "log:$(qs call harness logSeq "$kind")" >/dev/null
  shot "kind-$kind"
done

# The pause banner and the error strip over a decision.
call select decision:7 >/dev/null
qs call harness banners true >/dev/null
shot banners
qs call harness banners false >/dev/null
call select log >/dev/null

# The pointer over a Log row and over a rail tile, whose tooltip shows.
point 400 330
shot log-hover
point 46 250
shot rail-hover

# The sidebar open, on a session, with the pointer over another row.
call sidebar open
call select session:select-lag >/dev/null
point 200 375
shot sidebar-hover

# The New worker form, by its button in the title bar.
click 1315 83
shot spawn

# Its Model menu, under its button, which a press elsewhere closes.
click 480 447
shot spawn-model
click 900 300

closed
echo "views captured in $SNAPS"
