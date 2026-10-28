#!/usr/bin/env bash
# Drives the bosun panel through every call of the `bosun` IPC target, as
# BOSUN-IPC.md documents them, and checks what each one reports and refuses.
set -euo pipefail
# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

expect "isOpen before open" false "$(call isOpen)"
expect "state before open" false "$(field open)"
for c in "select desk" "focus pane" "mode full" "sidebar open" "arm pause" geometry; do
  # shellcheck disable=SC2086
  expect "$c with no panel" "error: no panel is open" "$(call $c)"
done

call open
await entered true
expect "isOpen" true "$(call isOpen)"
expect "opens on the waiting decision" decision:7 "$(field selected)"
expect "kind" decision "$(field kind)"
expect "mode" full "$(field mode)"
expect "sidebar" true "$(field sidebarOpen)"

# Selection
expect "select desk" ok "$(call select desk)"
expect "selected desk" desk "$(field selected)"
expect "kind desk" desk "$(field kind)"
expect "select session" ok "$(call select session:select-lag)"
expect "selected session" session:select-lag "$(field selected)"
expect "kind session" session "$(field kind)"
expect "select log" ok "$(call select log)"
expect "kind log" log "$(field kind)"
[[ $(field selected) == log:* ]] || fail "select log kept $(field selected)"
log=$(field selected)
call select desk >/dev/null
expect "select a log key" ok "$(call select "$log")"
expect "selected the log key" "$log" "$(field selected)"
expect "select decision" ok "$(call select decision:7)"
expect "selected decision" decision:7 "$(field selected)"
for bad in session:nobody decision:99 spawn bogus log:99999 ""; do
  got=$(call select "$bad")
  [[ $got == error:* ]] || fail "select '$bad' answered '$got'"
  expect "selection after refused '$bad'" decision:7 "$(field selected)"
done

# Mode and sidebar
full=$(call geometry)
expect "mode bogus" "error: no mode wide" "$(call mode wide)"
expect "sidebar closed" ok "$(call sidebar closed)"
expect "sidebar reads closed" false "$(field sidebarOpen)"
await focus rail
expect "sidebar toggle" ok "$(call sidebar toggle)"
expect "sidebar reads open" true "$(field sidebarOpen)"
expect "sidebar bogus" "error: no sidebar ajar" "$(call sidebar ajar)"
expect "mode overview" ok "$(call mode overview)"
expect "mode reads overview" overview "$(field mode)"
expect "kind overview" overview "$(field kind)"
over=$(call geometry)
echo "geometry full: $full"
echo "geometry overview: $over"
expect "overview width" 440 "$(jq .width <<<"$over")"
(($(jq .width <<<"$full") > 440)) || fail "the full panel is not wider"
expect "sidebar in the overview" "error: the overview has no sidebar" "$(call sidebar open)"
expect "focus pane in the overview" "error: no place pane in the overview" "$(call focus pane)"
expect "focus list in the overview" ok "$(call focus list)"
expect "focus in the overview" rows "$(field focus)"
expect "approve in the overview" "error: approve is not on offer here" "$(call arm approve)"
expect "select from the overview" ok "$(call select decision:7)"
expect "select opens the full panel" full "$(field mode)"

# Focus
expect "focus pane" ok "$(call focus pane)"
sleep 0.3
echo "focus after pane: $(field focus)"
expect "focus list" ok "$(call focus list)"
sleep 0.3
echo "focus after list: $(field focus)"
expect "focus bogus" "error: no place roof" "$(call focus roof)"

# Arming: the first press only, however often it is repeated
armed() { expect "armed after arm $1" "$2" "$(field armed)"; }
for action in approve:y deny:d; do
  expect "arm ${action%%:*}" ok "$(call arm "${action%%:*}")"
  armed "${action%%:*}" "${action##*:}"
  expect "arm ${action%%:*} again" ok "$(call arm "${action%%:*}")"
  expect "still armed after a repeat" "${action##*:}" "$(field armed)"
done
call select desk >/dev/null
expect "a selection disarms" "" "$(field armed)"
expect "approve off a decision" "error: approve is not on offer here" "$(call arm approve)"
expect "arm pause" ok "$(call arm pause)"
armed pause p
expect "arm clear" ok "$(call arm clear)"
armed clear C
call select session:select-lag >/dev/null
expect "clear off the desk" "error: clear is not on offer here" "$(call arm clear)"
expect "arm bogus" "error: no action burn" "$(call arm burn)"
expect "arm kill" ok "$(call arm kill)"
armed kill kill
expect "arm kill again" ok "$(call arm kill)"
armed kill kill
call select desk >/dev/null
expect "kill off a worker" "error: no worker is selected to kill" "$(call arm kill)"

# The three seconds run out
call arm pause >/dev/null
await armed ""

call close
expect "isOpen after close" false "$(call isOpen)"
expect "state after close" false "$(field open)"
expect "kept selection" desk "$(field selected)"
# Leaves the panel gone, not mid-close, for the next script.
for _ in $(seq 25); do
  [[ $(qs call harness panels) == 0 ]] && break
  sleep 0.2
done
expect "panels after close" 0 "$(qs call harness panels)"
echo "every bosun IPC call answered as documented"
