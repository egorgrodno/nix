# Reinstalls the bootloader of the NixOS on this machine's NIXROOT/NIXBOOT
# partitions, from a NixOS ISO. Nothing is rebuilt: the installed generation
# already describes its host.

mountPoint=/mnt
mounted=()
# systemd's record of a hibernation, which the next boot resumes from.
hibernateLocation=/sys/firmware/efi/efivars/HibernateLocation-8cf2644b-4b0b-428f-9387-6d876050dc67

die() {
  echo "repair-boot: $*" >&2
  exit 1
}

cleanup() {
  for ((i = ${#mounted[@]} - 1; i >= 0; i--)); do
    umount "${mounted[i]}" || true
  done
}
trap cleanup EXIT

# Reuses a mount that is already in place, so a half-finished manual repair
# does not have to be undone first.
mountLabel() {
  local dev=/dev/disk/by-label/$1 target=$2
  [[ -e $dev ]] || die "no partition labelled $1"
  if mountpoint -q "$target"; then
    [[ $(findmnt -no SOURCE "$target") == "$(readlink -f "$dev")" ]] ||
      die "$target is already mounted from another device"
    return
  fi
  mount --mkdir "${@:3}" "$dev" "$target"
  mounted+=("$target")
}

[[ $EUID -eq 0 ]] || die "must run as root"
[[ -d /sys/firmware/efi ]] || die "the ISO booted in legacy BIOS mode; boot it in UEFI mode"

# Resuming over a NIXROOT changed since the hibernation corrupts it, and a
# read-write mount changes it. Without the record no boot resumes, and swapon
# overwrites the stale image.
if [[ -e $hibernateLocation ]]; then
  echo "repair-boot: this machine is hibernated, and repairing it discards the session, unsaved work included"
  read -rp "Type discard to go on: " answer
  [[ $answer == discard ]] || die "left the hibernated machine alone"
  chattr -i "$hibernateLocation"
  rm "$hibernateLocation"
fi

mountLabel NIXROOT "$mountPoint"
mountLabel NIXBOOT "$mountPoint/boot" -o umask=077
[[ -e $mountPoint/nix/var/nix/profiles/system ]] || die "NIXROOT holds no NixOS system"

# Copied from nixos-install's bootloader step. Binding the root back to
# $mountPoint inside the chroot keeps absolute paths that the bootloader install
# references, such as initrd secrets, valid.
ln -sfn /proc/mounts "$mountPoint/etc/mtab"
export mountPoint
NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root "$mountPoint" -c "$(
  cat <<'EOF'
set -e
hash -r
echo "repair-boot: reinstalling the bootloader of $(cat /etc/hostname)"
mount --rbind --mkdir / "$mountPoint"
mount --make-rslave "$mountPoint"
/run/current-system/bin/switch-to-configuration boot
umount -R "$mountPoint" && (rmdir "$mountPoint" 2>/dev/null || true)
EOF
)"

efibootmgr || true
echo "repair-boot: done, reboot to reach GRUB"
