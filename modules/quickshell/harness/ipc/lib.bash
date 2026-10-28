# Sourced by the scripts beside it, which run.sh runs: it runs only *.sh.
# $QS and $QS_CONFIG name the harness's instance, $WLRCTL its pointer.

qs() { "$QS" ipc --path "$QS_CONFIG" "$@"; }
call() { qs call bosun "$@"; }
field() { call state | jq -r ".$1"; }

fail() {
  echo "FAIL: $*"
  exit 1
}

# expect <what> <wanted> <found>
expect() { [[ $2 == "$3" ]] || fail "$1: wanted '$2', found '$3'"; }

# Waits up to 5 s for the state field $1 to be $2.
await() {
  for _ in $(seq 25); do
    [[ $(field "$1") == "$2" ]] && return
    sleep 0.2
  done
  fail "state.$1: wanted '$2', found '$(field "$1")'"
}

# Closes the panel and waits until it is gone, not mid-close, for whatever
# comes next.
closed() {
  call close >/dev/null
  for _ in $(seq 25); do
    [[ $(qs call harness panels) == 0 ]] && return
    sleep 0.2
  done
}

# Moves the pointer to the output's x, y: to the corner, then across, ending
# on a step of a pixel, which a hover needs once the pointer is there.
point() {
  "$WLRCTL" pointer move -4000 -4000
  "$WLRCTL" pointer move $(($1 - 1)) $(($2 - 1))
  "$WLRCTL" pointer move 1 1
}

click() {
  point "$1" "$2"
  "$WLRCTL" pointer click left
  sleep 0.5
}
