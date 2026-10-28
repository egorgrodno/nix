#!/usr/bin/env bash
# Runs the bosun panel's scenarios offscreen and prints one line per scenario.
# See README.md next to this file.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
worktree=$(git -C "$here" rev-parse --show-toplevel)
variant=WORK
panes=session,desk
entries=50
steps=120
snaps=
timeout_s=300
keep=0

usage() {
  cat <<'EOF'
usage: run.sh [options] [scenario ...]

  -w DIR     worktree whose flake supplies the compositors, quickshell and the
             generated files (default: the one holding this script)
  -v VARIANT WORK for the worktree's QML, or a git revision of it (default WORK)
  -p PANES   session, desk, or session,desk (default both)
  -n N       entries per conversation (default 50)
  -s STEPS   frames of a scenario that sets none (default 120)
  -o DIR     where the snap scenario writes its PNGs
  -t SECONDS give up on one run after this long (default 300)
  -k         keep the scratch directory

A scenario is a file in scenarios/ (timed frames on a conversation, once per
pane) or in ipc/ (a script driving a live panel through `quickshell ipc`).
With none named, all run. HARNESS_HOST and HARNESS_USER (default fractal and
egor) pick the configuration the generated files come from. HARNESS_SIZE
(default 1440x900) sizes the screen the scripts in ipc/ drive.
EOF
}

while getopts "w:v:p:n:s:o:t:kh" opt; do
  case $opt in
  w) worktree=$(cd "$OPTARG" && pwd) ;;
  v) variant=$OPTARG ;;
  p) panes=$OPTARG ;;
  n) entries=$OPTARG ;;
  s) steps=$OPTARG ;;
  o) snaps=$(mkdir -p "$OPTARG" && cd "$OPTARG" && pwd) ;;
  t) timeout_s=$OPTARG ;;
  k) keep=1 ;;
  *)
    usage
    exit 2
    ;;
  esac
done
shift $((OPTIND - 1))

names=("$@")
if ((${#names[@]} == 0)); then
  for f in "$here"/scenarios/*.qml "$here"/ipc/*.sh; do
    [[ -f $f ]] && names+=("$(basename "$f" | sed 's/\.[a-z]*$//')")
  done
fi
frames=()
scripts=()
for name in "${names[@]}"; do
  if [[ -f $here/scenarios/$name.qml ]]; then
    frames+=("$name")
  elif [[ -f $here/ipc/$name.sh ]]; then
    scripts+=("$name")
  else
    echo "no scenario $name in $here/scenarios or $here/ipc" >&2
    exit 2
  fi
done

host=${HARNESS_HOST:-fractal}
user=${HARNESS_USER:-egor}

# The scratch directory is the runtime directory, which keeps the harness's
# sockets clear of the live session's. A socket's path holds 107 bytes and
# Quickshell's IPC socket sits 35 below the runtime directory, so the name
# stays short.
work=$(mktemp -d "${TMPDIR:-/tmp}/q.XXXX")
runtime=$work

# Only the processes started here are ever signalled, by PID.
pids=()
# Set when the scratch directory, with its logs, is worth keeping, and when
# a run gave no results.
failed=0
status=0
cleanup() {
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  if ((keep == 0 && failed == 0)); then
    rm -rf "$work"
  else
    echo "scratch kept in $work" >&2
  fi
}
trap cleanup EXIT
trap 'failed=1; exit 130' INT TERM

attr="$worktree#nixosConfigurations.$host"
home="$attr.config.home-manager.users.$user"
built=$(nix build --no-link --print-out-paths \
  "$attr.pkgs.weston" \
  "$attr.pkgs.labwc" \
  "$attr.pkgs.grim" \
  "$attr.pkgs.wlrctl" \
  "$attr.pkgs.wlr-randr" \
  "$home.programs.quickshell.package" \
  "$home.xdg.configFile.\"quickshell/Theme.qml\".source" \
  "$home.xdg.configFile.\"quickshell/Programs.qml\".source" \
  "$home.xdg.configFile.\"quickshell/Host.qml\".source" \
  "$home.xdg.configFile.\"quickshell/symbols.json\".source") || {
  failed=1
  exit 1
}
weston= labwc= grim= wlrctl= randr= quickshell=
generated=()
while read -r path; do
  case $path in
  *-weston-*) weston=$path ;;
  *-man) ;;
  *-grim-*) grim=$path ;;
  *-wlrctl-*) wlrctl=$path ;;
  *-wlr-randr-*) randr=$path ;;
  *-labwc-*) labwc=$path ;;
  *-quickshell-*) quickshell=$path ;;
  *) generated+=("$path") ;;
  esac
done <<<"$built"

# The panel's QML as the variant has it, then what nix generates, then the
# harness on top.
config=$work/config
mkdir "$config"
if [[ $variant == WORK ]]; then
  cp "$worktree"/modules/quickshell/*.qml "$config"/
else
  git -C "$worktree" archive "$variant" modules/quickshell |
    tar -x -C "$config" --strip-components=2 --no-wildcards-match-slash --wildcards 'modules/quickshell/*.qml'
fi
for path in "${generated[@]}"; do
  cp "$path" "$config/${path#*-}"
done
chmod -R u+w "$config"
# The panel must not reach the user's daemon, or run its commands, or post
# the fake decisions to the user's notifications.
sed -i -e 's#property string bosun: ".*"#property string bosun: "/nonexistent/bosun"#' \
  -e 's#property string notifySend: ".*"#property string notifySend: "/nonexistent/notify-send"#' "$config/Programs.qml"
# With no Hyprland there is no focused monitor for the pill's screen to equal.
sed -i 's#agents.QsWindow.window?.screen === Bosun.screen#true#' "$config/Agents.qml"
cp "$here/shell.qml" "$here/panel.qml" "$here/HarnessData.qml" "$config"/
for name in "${frames[@]}"; do
  cp "$here/scenarios/$name.qml" "$config/scn-$name.qml"
done
mkdir "$work/state"

# Starts the compositor `$@` with its log in `$work`, and waits for its socket
# `$display`. Weston draws the timed frames; it has no layer shell, which the
# panel's windows need, so those run on labwc.
compositor() {
  env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY \
    XDG_RUNTIME_DIR="$runtime" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    "$@" >"$work/$display.log" 2>&1 &
  pids+=($!)
  for _ in $(seq 50); do
    [[ -S $runtime/$display ]] && return
    sleep 0.2
  done
  echo "the compositor for $display did not start:" >&2
  tail -n 5 "$work/$display.log" >&2
  failed=1
  exit 1
}

# Starts the shell `$1` in the background with the environment that makes it
# the harness's own, logging to `$2`; its PID is left in `$qs_pid`.
launch() {
  env -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
    XDG_RUNTIME_DIR="$runtime" XDG_STATE_HOME="$work/state" WAYLAND_DISPLAY="$display" \
    QT_QPA_PLATFORM=wayland LIBGL_ALWAYS_SOFTWARE=1 QS_DISABLE_CRASH_HANDLER=1 \
    PANE="${pane:-}" SCENARIOS="$scenario_list" N="$entries" STEPS="$steps" SNAPS="$snaps" \
    timeout "$timeout_s" "$quickshell/bin/quickshell" -p "$config/$1" --no-color >"$2" 2>&1 &
  qs_pid=$!
  pids+=("$qs_pid")
}

# The log's own warnings and errors, apart from the ones a headless run with
# no daemon always has.
problems() {
  local found
  found=$(grep -E '(WARN|ERROR)' "$1" | grep -viE 'hyprland|nonexistent|window masks|portal|dbus|a11y|libseat|wayland' || true)
  if [[ -n $found ]]; then
    echo "$2: $(wc -l <<<"$found") warnings, first: $(head -n 1 <<<"$found" | cut -c1-200)"
    failed=1
  fi
}

scenario_list=$(
  IFS=,
  echo "${frames[*]}"
)
echo "variant=$variant n=$entries worktree=$worktree"

if ((${#frames[@]} > 0)); then
  display=wl-h
  compositor "$weston/bin/weston" --backend=headless --renderer=pixman --socket=$display --width=1280 --height=1024
  for pane in ${panes//,/ }; do
    log=$work/$pane.log
    launch shell.qml "$log"
    wait "$qs_pid" || true
    sed -n 's/.*HARNESS //p' "$log" | grep -v '^injected '
    problems "$log" "$pane"
    if ! grep -qE "HARNESS $pane .*(frames=|skipped)" "$log"; then
      echo "$pane: no results; the end of its log:" >&2
      tail -n 8 "$log" >&2
      failed=1
      status=1
    fi
  done
fi

if ((${#scripts[@]} > 0)); then
  pane=
  display=wayland-0
  compositor "$labwc/bin/labwc"
  # The size of the screen the panel fills, as on the thinkpad.
  env XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY="$display" "$randr/bin/wlr-randr" --output HEADLESS-1 --custom-mode "${HARNESS_SIZE:-1440x900}" || {
    echo "the labwc output could not be resized" >&2
    failed=1
    exit 1
  }
  log=$work/panel.log
  launch panel.qml "$log"
  for _ in $(seq 100); do
    grep -q 'HARNESS ready' "$log" && break
    sleep 0.3
  done
  if ! grep -q 'HARNESS ready' "$log"; then
    echo "panel: did not come up; the end of its log:" >&2
    tail -n 8 "$log" >&2
    failed=1
    status=1
  else
    for name in "${scripts[@]}"; do
      # The scripts find the instance by its config, in the harness's runtime
      # directory, where no `quickshell` of the live session can answer.
      if out=$(env -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY="$display" GRIM="$grim/bin/grim" WLRCTL="$wlrctl/bin/wlrctl" QS="$quickshell/bin/quickshell" QS_CONFIG="$config/panel.qml" SNAPS="$snaps" \
        timeout 120 bash "$here/ipc/$name.sh" 2>&1); then
        sed "s/^/ipc $name: /" <<<"$out"
      else
        sed "s/^/ipc $name: /" <<<"$out"
        echo "ipc $name: FAILED"
        failed=1
        status=1
      fi
    done
    problems "$log" panel
  fi
fi
exit "$status"
