#!/usr/bin/env bash
# Opens and closes the bosun panel through the bar's IPC target. A script
# prints what it found and exits non-zero on a failure; `run.sh` supplies $QS
# and $QS_CONFIG, which name the instance, and the runtime directory it sits in.
set -euo pipefail

qs() { "$QS" ipc --path "$QS_CONFIG" "$@"; }

# Waits up to 5 s for the harness target to report $1 panels.
panels() {
  for _ in $(seq 25); do
    [[ $(qs call harness panels) == "$1" ]] && return
    sleep 0.2
  done
  echo "expected $1 panels, found $(qs call harness panels)"
  exit 1
}

qs call bosun toggle
panels 1
qs call bosun toggle
panels 0
echo "toggle opened the panel and closed it"
