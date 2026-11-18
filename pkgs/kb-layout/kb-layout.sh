# Saves the machine's keyboard layout, which the editors, shells, bar and
# Hyprland read, then runs each executable in this account's hooks directory
# with it, for what lives outside this flake. An empty or missing file means
# qwerty.
#
# Usage: kb-layout [qwerty | hallmack | toggle]; without one it prints the
# saved layout.

file=/var/lib/keyboard-layout
hooks=${XDG_CONFIG_HOME:-$HOME/.config}/keyboard-layout/hooks

saved=$(cat "$file" 2>/dev/null || true)
[[ $saved == hallmack ]] || saved=qwerty

case ${1-} in
"")
  echo "$saved"
  exit 0
  ;;
qwerty | hallmack) layout=$1 ;;
toggle) if [[ $saved == hallmack ]]; then layout=qwerty; else layout=hallmack; fi ;;
*)
  echo "usage: kb-layout [qwerty | hallmack | toggle]" >&2
  exit 2
  ;;
esac

# NixOS creates the file writable by every account; elsewhere it takes root once.
if [[ ! -w $file ]]; then
  echo "kb-layout: cannot write $file; create it with" >&2
  echo "  sudo install -m 664 -g $(id -gn) /dev/null $file" >&2
  exit 1
fi
# Rewritten in place: a rename would drop the mode that lets other accounts write it.
echo "$layout" >"$file"

failed=0
for hook in "$hooks"/*; do
  [[ -x $hook ]] || continue
  if ! "$hook" "$layout"; then
    echo "kb-layout: $hook failed" >&2
    failed=1
  fi
done
exit "$failed"
