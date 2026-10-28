#!/usr/bin/env bash
# Takes a PNG of each pane of the expanded panel into $SNAPS, for comparing
# looks between revisions. $GRIM captures the harness compositor's own screen.
set -euo pipefail

[[ -n ${SNAPS:-} ]] || {
  echo "views: no -o DIR to write the PNGs to"
  exit 0
}

qs() { "$QS" ipc --path "$QS_CONFIG" "$@"; }
call() { qs call bosun "$@"; }
field() { call state | jq -r ".$1"; }

# Lets the panel settle, then captures it as $1.
shot() {
  sleep 1
  "$GRIM" "$SNAPS/$1.png"
}

call open
for _ in $(seq 25); do
  [[ $(field entered) == true ]] && break
  sleep 0.2
done
call mode expanded

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

# The pointer over a Log row and over a rail button.
"$WLRCTL" pointer move -4000 -4000
"$WLRCTL" pointer move 400 330
shot log-hover
"$WLRCTL" pointer move -400 -141
shot rail-hover

# The sidebar beside the rail, on a session, with the pointer over another row.
call mode sidebar
call select session:select-lag >/dev/null
"$WLRCTL" pointer move -4000 -4000
"$WLRCTL" pointer move 200 415
shot sidebar-hover
call mode expanded

# The New worker form, by its button in the title bar.
"$WLRCTL" pointer move -4000 -4000
"$WLRCTL" pointer move 1157 85
"$WLRCTL" pointer click left
shot spawn

# Its Model menu, under its button, which a press elsewhere closes.
"$WLRCTL" pointer move -4000 -4000
"$WLRCTL" pointer move 160 449
"$WLRCTL" pointer click left
shot spawn-model
"$WLRCTL" pointer move -4000 -4000
"$WLRCTL" pointer move 600 300
"$WLRCTL" pointer click left

# Leaves the panel gone, not mid-close, for the next script.
call close
for _ in $(seq 25); do
  [[ $(qs call harness panels) == 0 ]] && break
  sleep 0.2
done
echo "views captured in $SNAPS"
