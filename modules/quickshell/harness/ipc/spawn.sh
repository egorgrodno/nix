#!/usr/bin/env bash
# The New worker form: a click anywhere in its task field, which must keep
# the keyboard there.
set -euo pipefail
# shellcheck source=lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

before=
trap '[[ -z $before ]] || call select "$before" >/dev/null 2>&1 || true; call close >/dev/null 2>&1 || true' EXIT
closed

call open
await entered true
call mode full >/dev/null
before=$(field selected)
expect "the form opens" ok "$(qs call harness spawn)"
await kind spawn

# Into the task's first line, then below it with the keyboard in the field,
# which Panel.qml's blur takes from a field a press misses, and from the list
# into the margins past the text.
task=$(qs call harness spawnForm | jq .task)
tap() {
  click $(($(jq .x <<<"$task") + $1)) $(($(jq .y <<<"$task") + $2))
  expect "focus after a click at $1,$2 in the task field" field "$(field focus)"
}
call focus list >/dev/null
[[ $(field focus) != field ]] || fail "focus list left the keyboard in a field"
tap 40 20
tap 40 120
tap $(($(jq .width <<<"$task") - 6)) $(($(jq .height <<<"$task") - 6))
call focus list >/dev/null
tap 5 $(($(jq .height <<<"$task") / 2))
echo "the task field takes a click anywhere"
