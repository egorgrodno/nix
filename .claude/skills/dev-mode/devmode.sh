#!/usr/bin/env bash
# Swap home-manager's read-only store symlinks for writable copies, so a config
# can be edited and reloaded live instead of through a nixos-rebuild.
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nix-devmode"
EDITS="$STATE/edits"
INHIBIT="$STATE/inhibit.pid"

die() {
  printf 'devmode: %s\n' "$*" >&2
  exit 1
}
note() { printf '%s\n' "$*" >&2; }

# name -> home-relative paths it owns (file or directory)
paths_of() {
  case "$1" in
  quickshell) echo ".config/quickshell" ;;
  hyprland) echo ".config/hypr/hyprland.lua" ;;
  hypridle) echo ".config/hypr/hypridle.conf" ;;
  kitty) echo ".config/kitty" ;;
  nvim) echo ".config/nvim" ;;
  zsh) echo ".config/zsh" ;;
  git) echo ".config/git" ;;
  gtk) echo ".config/gtk-3.0 .config/gtk-4.0 .gtkrc-2.0" ;;
  vifm) echo ".config/vifm" ;;
  ripgrep) echo ".config/ripgrep" ;;
  less) echo ".config/lesskey" ;;
  mimeapps) echo ".config/mimeapps.list" ;;
  udiskie) echo ".config/udiskie" ;;
  *) echo ".config/$1" ;;
  esac
}

# name -> command that makes the running program re-read its config
reload_of() {
  case "$1" in
  hyprland) echo "hyprctl reload" ;;
  hypridle) echo "systemctl --user restart hypridle" ;;
  # Quickshell watches the files it loaded, not the copies `on` puts in their
  # place, so it needs a restart before it reloads on save.
  quickshell) echo "systemctl --user restart quickshell" ;;
  kitty) echo "pkill -USR1 kitty" ;;
  *) echo "" ;;
  esac
}

# name -> what to do when there is no reload signal
manual_of() {
  case "$1" in
  nvim) echo "open a new nvim, or :source the file" ;;
  zsh) echo "run 'exec zsh' in the shell you are testing" ;;
  gtk) echo "restart the GTK application" ;;
  *) echo "restart the program" ;;
  esac
}

# Every managed file under a name: store symlinks (locked) and files listed in state (unlocked).
files_of() {
  local name=$1 p abs
  for p in $(paths_of "$name"); do
    abs="$HOME/$p"
    [ -e "$abs" ] || [ -L "$abs" ] || continue
    if [ -d "$abs" ] && [ ! -L "$abs" ]; then
      find "$abs" -type l -o -type f
    else
      printf '%s\n' "$abs"
    fi
  done
}

state_file() { printf '%s/%s.tsv\n' "$STATE" "$1"; }

# The plain files under a name as `on` first found them, which `off` leaves
# alone: anything else plain was made while unlocked.
plain_file() { printf '%s/%s.plain\n' "$STATE" "$1"; }

# Plain files made while unlocked: neither recorded nor there at `on`.
new_files_of() {
  local name=$1 file plain
  plain=$(plain_file "$name")
  while IFS= read -r file; do
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    [ -z "$(origin_of "$name" "$file")" ] || continue
    [ -f "$plain" ] && grep -Fxq -- "$file" "$plain" && continue
    printf '%s\n' "$file"
  done < <(files_of "$name")
}

origin_of() { # name file -> recorded store path, empty if not in dev mode
  local s
  s=$(state_file "$1")
  [ -f "$s" ] || return 0
  awk -F'\t' -v f="$2" '$1 == f { print $2 }' "$s"
}

# The home-manager-files directory the live tree currently uses. Read from a file
# dev mode never touches, so an activation that lands mid-session is detectable.
current_hm_files() {
  local ref t
  for ref in .config/environment.d/10-home-manager.conf .config/git/config \
    .config/gtk-3.0/settings.ini .icons/default/index.theme; do
    [ -L "$HOME/$ref" ] || continue
    t=$(readlink "$HOME/$ref")
    case "$t" in
    /nix/store/*-home-manager-files/*)
      printf '%s-home-manager-files\n' "${t%%-home-manager-files/*}"
      return 0
      ;;
    esac
  done
}

active_names() {
  [ -d "$STATE" ] || return 0
  find "$STATE" -maxdepth 1 -name '*.tsv' -printf '%f\n' 2>/dev/null | sed 's/\.tsv$//' | sort
}

# On a laptop, idle, sleep and the lid switch stay off while anything is
# unlocked, so the screen stays up for screenshots and a suspend cannot cut a
# session short. base.isLaptop pins the chassis hostnamed reports.
inhibitor_held() {
  local pid
  pid=$(cat "$INHIBIT" 2>/dev/null) || return 1
  [ -n "$pid" ] && grep -qa systemd-inhibit "/proc/$pid/cmdline" 2>/dev/null
}

inhibit() {
  [ "$(hostnamectl chassis 2>/dev/null)" = laptop ] || return 0
  inhibitor_held && return 0
  # A session of its own, so releasing its process group ends the sleep too.
  setsid systemd-inhibit --what=idle:sleep:handle-lid-switch --mode=block \
    --who="dev mode" --why="configs unlocked for live editing" \
    sleep infinity </dev/null >/dev/null 2>&1 &
  echo $! >"$INHIBIT"
  note "holding off idle, sleep and the lid switch until the last program is relocked"
}

release() {
  [ -z "$(active_names)" ] || return 0
  if inhibitor_held; then
    kill -- "-$(cat "$INHIBIT")" 2>/dev/null || true
    note "released the idle, sleep and lid switch inhibitor"
  fi
  rm -f "$INHIBIT"
}

cmd_on() {
  [ $# -gt 0 ] || die "usage: devmode on <program>..."
  mkdir -p "$STATE"
  local name file origin s plain
  for name in "$@"; do
    s=$(state_file "$name")
    touch "$s"
    plain=$(plain_file "$name")
    if [ ! -f "$plain" ]; then
      files_of "$name" | while IFS= read -r file; do
        [ -L "$file" ] || printf '%s\n' "$file"
      done >"$plain"
    fi
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if [ -L "$file" ]; then
        # The immediate target, not the resolved one: home-manager's collision
        # check matches `readlink` output against /nix/store/*-home-manager-files/*,
        # so restoring anything else makes the next activation abort.
        origin=$(readlink "$file")
        case "$origin" in
        /nix/store/*-home-manager-files/*) ;;
        *) continue ;; # not home-manager's, leave it alone
        esac
        rm "$file"
        cp "$origin" "$file"
        chmod u+w "$file"
        printf '%s\t%s\n' "$file" "$origin" >>"$s"
        printf 'unlocked %s\n' "${file#"$HOME"/}"
      elif [ -n "$(origin_of "$name" "$file")" ]; then
        printf 'already unlocked %s\n' "${file#"$HOME"/}"
      fi
    done < <(files_of "$name")
    if [ ! -s "$s" ]; then
      rm -f "$s" "$plain"
      note "$name: no store-managed files under $(paths_of "$name")"
      continue
    fi
    local r
    r=$(reload_of "$name")
    if [ -n "$r" ]; then
      note "$name: edit, then '$0 reload $name' (or '$0 watch $name') — $r"
    else
      note "$name: edit, then $(manual_of "$name")"
    fi
  done
  [ -z "$(active_names)" ] || inhibit
  note ""
  note "Run '$0 off --all' before nixos-rebuild; activation aborts on files it does not own."
}

cmd_off() {
  local names
  if [ "${1:-}" = "--all" ]; then
    mapfile -t names < <(active_names)
  else
    [ $# -gt 0 ] || die "usage: devmode off <program>...|--all"
    names=("$@")
  fi
  [ ${#names[@]} -gt 0 ] || {
    note "nothing in dev mode"
    release
    return 0
  }
  local name s file origin rel cur target base relhm
  cur=$(current_hm_files)
  for name in "${names[@]}"; do
    s=$(state_file "$name")
    [ -f "$s" ] || {
      note "$name: not in dev mode"
      continue
    }
    while IFS=$'\t' read -r file origin; do
      [ -n "$file" ] || continue
      # An activation may have landed while dev mode was on, relinking every file
      # it did own to a new generation. Restore into that one, not the captured one.
      relhm=${origin#*-home-manager-files/}
      base=${origin%%-home-manager-files/*}-home-manager-files
      target=$origin
      if [ -n "$cur" ] && [ "$base" != "$cur" ] && [ -e "$cur/$relhm" ]; then
        target="$cur/$relhm"
        note "$name: generation moved while unlocked; relinking $relhm to the current one"
      fi
      [ -e "$target" ] || die "$name: store origin gone ($target); rebuild first"
      if [ -f "$file" ] && ! cmp -s "$file" "$origin"; then
        rel=${file#"$HOME"/}
        mkdir -p "$EDITS/$name/$(dirname "$rel")"
        cp "$file" "$EDITS/$name/$rel"
        diff -u --label "nix:$rel" --label "dev:$rel" "$origin" "$file" \
          >"$EDITS/$name/$rel.patch" || true
        printf 'saved edits  %s -> %s\n' "$rel" "$EDITS/$name/$rel"
      fi
      rm -f "$file"
      ln -s "$target" "$file"
      printf 'relocked     %s\n' "${file#"$HOME"/}"
    done <"$s"
    # Home-manager skips a plain file that matches what it would link, leaving
    # it plain, and aborts on one that differs. One the current generation holds
    # is linked into it, its own bytes saved should they differ; any other is
    # moved in with the saved edits.
    while IFS= read -r file; do
      rel=${file#"$HOME"/}
      mkdir -p "$EDITS/$name/$(dirname "$rel")"
      if [ -n "$cur" ] && [ -e "$cur/$rel" ]; then
        if ! cmp -s "$file" "$cur/$rel"; then
          cp "$file" "$EDITS/$name/$rel"
          diff -u --label "nix:$rel" --label "dev:$rel" "$cur/$rel" "$file" \
            >"$EDITS/$name/$rel.patch" || true
          printf 'saved edits  %s -> %s\n' "$rel" "$EDITS/$name/$rel"
        fi
        rm -f "$file"
        ln -s "$cur/$rel" "$file"
        printf 'linked new   %s\n' "$rel"
      else
        mv "$file" "$EDITS/$name/$rel"
        printf 'moved new    %s -> %s (in no generation yet)\n' "$rel" "$EDITS/$name/$rel"
      fi
    done < <(new_files_of "$name")
    rm -f "$s" "$(plain_file "$name")"
  done
  release
}

cmd_status() {
  local names
  mapfile -t names < <(active_names)
  if inhibitor_held; then echo "inhibiting idle, sleep and the lid switch (pid $(cat "$INHIBIT"))"; fi
  [ ${#names[@]} -gt 0 ] || {
    echo "nothing in dev mode"
    return 0
  }
  local name file origin mark
  for name in "${names[@]}"; do
    echo "$name"
    while IFS=$'\t' read -r file origin; do
      [ -n "$file" ] || continue
      if cmp -s "$file" "$origin"; then mark="  unchanged"; else mark="* EDITED   "; fi
      printf '  %s %s\n' "$mark" "${file#"$HOME"/}"
    done <"$(state_file "$name")"
    while IFS= read -r file; do
      printf '  + NEW       %s\n' "${file#"$HOME"/}"
    done < <(new_files_of "$name")
  done
}

cmd_diff() {
  local names
  if [ $# -gt 0 ]; then names=("$@"); else mapfile -t names < <(active_names); fi
  [ ${#names[@]} -gt 0 ] || {
    note "nothing in dev mode"
    return 0
  }
  local name file origin rel
  for name in "${names[@]}"; do
    local s
    s=$(state_file "$name")
    [ -f "$s" ] || {
      note "$name: not in dev mode"
      continue
    }
    while IFS=$'\t' read -r file origin; do
      [ -n "$file" ] || continue
      rel=${file#"$HOME"/}
      diff -u --label "nix:$rel" --label "dev:$rel" "$origin" "$file" || true
    done <"$s"
  done
}

cmd_reload() {
  [ $# -gt 0 ] || die "usage: devmode reload <program>..."
  local name r
  for name in "$@"; do
    r=$(reload_of "$name")
    if [ -z "$r" ]; then
      note "$name: no reload signal — $(manual_of "$name")"
      continue
    fi
    if eval "$r" 2>/dev/null; then
      printf 'reloaded %s\n' "$name"
    else
      note "$name: '$r' failed — is it running?"
    fi
  done
}

cmd_watch() {
  [ $# -gt 0 ] || die "usage: devmode watch <program>..."
  local name
  for name in "$@"; do
    [ -f "$(state_file "$name")" ] || die "$name: not in dev mode (run 'devmode on $name')"
  done
  note "watching ${*}; Ctrl-C to stop"
  local prev="" cur
  while :; do
    cur=$(for name in "$@"; do
      while IFS=$'\t' read -r file _; do
        [ -f "$file" ] && stat -c '%n %Y %s' "$file"
      done <"$(state_file "$name")"
    done | sort)
    if [ -n "$prev" ] && [ "$cur" != "$prev" ]; then
      printf -- '--- change detected\n'
      cmd_reload "$@" || true
    fi
    prev=$cur
    sleep 0.5
  done
}

# The flake attribute that generates a given live file. Quoted attribute names
# work in an installable path, so the dots inside a filename are safe.
attr_for() {
  local rel=${1#"$HOME"/} host base
  host=$(cat /etc/hostname)
  base=".#nixosConfigurations.$host.config.home-manager.users.$USER"
  case "$rel" in
  .config/*) printf '%s.xdg.configFile."%s".source' "$base" "${rel#.config/}" ;;
  *) printf '%s.home.file."%s".source' "$base" "$rel" ;;
  esac
}

# Rebuild each unlocked file from the Nix source and compare it to the live copy.
# Identical means the edits have been ported faithfully; a diff is what is still
# missing from the source, and would be lost on the next rebuild.
cmd_verify() {
  local names
  if [ $# -gt 0 ]; then names=("$@"); else mapfile -t names < <(active_names); fi
  [ ${#names[@]} -gt 0 ] || {
    note "nothing in dev mode"
    return 0
  }
  local name file origin rel attr out rc=0
  for name in "${names[@]}"; do
    local s
    s=$(state_file "$name")
    [ -f "$s" ] || {
      note "$name: not in dev mode"
      continue
    }
    while IFS=$'\t' read -r file origin; do
      [ -n "$file" ] || continue
      rel=${file#"$HOME"/}
      attr=$(attr_for "$file")
      if ! out=$(nix build --no-link --print-out-paths "$attr" 2>/dev/null); then
        printf '?  %-38s could not evaluate %s\n' "$rel" "$attr"
        rc=1
        continue
      fi
      if cmp -s "$out" "$file"; then
        printf 'ok %-38s source regenerates it exactly\n' "$rel"
      else
        printf 'XX %-38s source does NOT match the live file:\n' "$rel"
        diff -u --label "nix:$rel" --label "dev:$rel" "$out" "$file" || true
        rc=1
      fi
    done <"$s"
  done
  return $rc
}

cmd_list() {
  echo "known targets:"
  for name in quickshell hyprland hypridle kitty nvim zsh git gtk vifm ripgrep less mimeapps udiskie; do
    printf '  %-10s %s\n' "$name" "$(paths_of "$name")"
  done
  echo "any other name falls back to .config/<name>"
}

cmd_preflight() {
  local names
  mapfile -t names < <(active_names)
  [ ${#names[@]} -eq 0 ] || die "in dev mode: ${names[*]} — run '$0 off --all' first"
  echo "clean"
}

case "${1:-}" in
on)
  shift
  cmd_on "$@"
  ;;
off)
  shift
  cmd_off "$@"
  ;;
status)
  shift
  cmd_status "$@"
  ;;
diff)
  shift
  cmd_diff "$@"
  ;;
verify)
  shift
  cmd_verify "$@"
  ;;
reload)
  shift
  cmd_reload "$@"
  ;;
watch)
  shift
  cmd_watch "$@"
  ;;
list)
  shift
  cmd_list "$@"
  ;;
preflight)
  shift
  cmd_preflight "$@"
  ;;
*) die "usage: devmode {on|off|status|diff|verify|reload|watch|list|preflight} [program...]" ;;
esac
