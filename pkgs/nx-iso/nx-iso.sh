# Builds the rescue stick's ISO, letting in over SSH the public keys in
# rescue/authorized_keys, and prints its path. Git ignores that file, which
# hides it from the flake, so the build is impure and adds it from outside.
#
# Usage: nx-iso [flake], which defaults to /etc/nixos.

flake=$(realpath "${1:-/etc/nixos}")
keys=$flake/rescue/authorized_keys

die() {
  echo "nx-iso: $*" >&2
  exit 1
}

[[ -f $flake/rescue/configuration.nix ]] || die "$flake has no rescue/configuration.nix"

if [[ ! -e $keys ]]; then
  cat >"$keys" <<'EOF'
# Public keys that may SSH into the rescue stick as root or nixos, one per line.
# Git ignores this file; nx-iso reads it.
EOF
  die "created $keys: add the public keys to let in, then run nx-iso again"
fi
grep -qv '^[[:space:]]*\(#\|$\)' "$keys" ||
  echo "nx-iso: $keys lists no keys, so the stick will refuse SSH" >&2

# As a bare path, getFlake would copy the whole directory into the ISO's
# /etc/nixos, .git and ignored files included.
out=$(
  nix build --impure --no-link --print-out-paths \
    --argstr flake "git+file://$flake" --argstr keys "$keys" --expr '
      { flake, keys }:
      let
        rescue = (builtins.getFlake flake).nixosConfigurations.rescue.extendModules {
          modules = [
            {
              users.users.root.openssh.authorizedKeys.keyFiles = [ (/. + keys) ];
              users.users.nixos.openssh.authorizedKeys.keyFiles = [ (/. + keys) ];
            }
          ];
        };
      in
      rescue.config.system.build.isoImage
    '
)
echo "nx-iso: built the ISO below; nx-flash writes it over a USB stick" >&2
echo "$out"/iso/*.iso
