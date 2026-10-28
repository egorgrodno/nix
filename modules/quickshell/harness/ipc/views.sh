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

for row in decision:7 desk session:select-lag session:panel-ipc log; do
  call select "$row" >/dev/null
  shot "${row%%:*}-${row##*:}"
done

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
"$WLRCTL" pointer move 600 300
"$WLRCTL" pointer click left
echo "views captured in $SNAPS"
