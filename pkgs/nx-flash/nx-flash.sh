# Writes the rescue ISO, or another one, over a USB disk picked from a list,
# then reads it back to compare. A disk with a mount outside /media, where
# the desktop's mountOnMedia puts sticks, is left off the list, so the running
# system's own disks never show.
#
# Usage: nx-flash [iso], which defaults to the ISO nx-iso builds.

die() {
  echo "nx-flash: $*" >&2
  exit 1
}

# As root, nx-iso would build and create rescue/authorized_keys as root too.
[[ $EUID -ne 0 ]] || die "run it as yourself; it calls sudo for the write"

iso=${1:-$(nx-iso)}
[[ -f $iso ]] || die "no ISO at $iso"
isoBytes=$(stat -c %s "$iso")

mapfile -t disks < <(
  lsblk -Jbpo NAME,TYPE,TRAN,SIZE,MOUNTPOINTS | jq -r --argjson min "$isoBytes" '
    .blockdevices[]
    | select(.type == "disk" and .tran == "usb" and .size >= $min)
    | select(all(.. | objects | .mountpoints[]? | select(. != null); startswith("/media/")))
    | .name
  '
)
((${#disks[@]})) || die "no USB disk of $(numfmt --to=iec "$isoBytes") or more to write to"

choices=()
for disk in "${disks[@]}"; do
  choices+=("$disk  $(lsblk -dno SIZE,VENDOR,MODEL "$disk" | xargs)  $(lsblk -no LABEL "$disk" | xargs)")
done
choice=$(gum choose --header "USB disk to overwrite with $(basename "$iso")" "${choices[@]}")
disk=${choice%% *}

lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$disk"
[[ $(gum input --header "Type $disk to overwrite it") == "$disk" ]] || die "left $disk alone"

mapfile -t mounted < <(
  lsblk -Jpo NAME,MOUNTPOINTS "$disk" |
    jq -r '.. | objects | select(any(.mountpoints[]?; . != null)) | .name'
)
for part in "${mounted[@]}"; do
  sudo umount "$part"
done

sudo dd if="$iso" of="$disk" bs=4M status=progress oflag=sync

# Direct reads skip the page cache, which still holds what was just written.
echo "nx-flash: reading $disk back"
sudo dd if="$disk" bs=4M count="$isoBytes" iflag=direct,count_bytes status=progress |
  cmp - "$iso" ||
  die "$disk differs from the ISO: write it again, or use another stick"

echo "nx-flash: $disk holds $(basename "$iso")"
