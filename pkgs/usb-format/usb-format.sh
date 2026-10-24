# Formats a USB disk, whole or one of its partitions, through UDisks2, which
# lets the active session do so without a password. The bar's format panel
# polls `list` and starts `format` in a scope of its own, which reports how it
# ended as a notification, so the panel can close or the bar restart under it.
# As in nx-flash, a disk with a mount outside /media, where the desktop's
# mountOnMedia puts sticks, is left off the list.
#
# Usage:
#   usb-format list
#   usb-format format <device> vfat|exfat|ntfs|ext4 <label> quick|full
#   usb-format cancel <device>
#
# A whole disk gets an MBR table with one partition, as Windows, cameras and
# car stereos read. A partition keeps its place, its MBR type changed to fit.

# A format running from here holds a file named after its disk, with its PID.
runtime=${XDG_RUNTIME_DIR:?}/usb-format

notify() {
  notify-send --app-name="USB format" --icon=drive-removable-media-usb "$@"
}

die() {
  echo "usb-format: $1" >&2
  if [[ -n ${title:-} ]]; then
    notify --urgency=critical "Could not format $title" "$1"
  fi
  exit 1
}

# Waits as long as the method runs, as a full format writes the whole disk.
call() {
  local out
  if ! out=$(busctl --system --json=short --timeout=infinity call -- org.freedesktop.UDisks2 "$@" 2>&1); then
    if [[ -n ${title:-} && $out == *"Job was canceled"* ]]; then
      notify "Stopped formatting $title" "It holds no filesystem until formatted again."
      exit 1
    fi
    die "${out#Call failed: }"
  fi
  printf '%s\n' "$out"
}

object() {
  local path
  path=$(call /org/freedesktop/UDisks2/Manager org.freedesktop.UDisks2.Manager ResolveDevice 'a{sv}a{sv}' 1 path s "$1" 0 | jq -r '.data[0][0] // empty')
  [[ -n $path ]] || die "UDisks2 does not know $1"
  printf '%s\n' "$path"
}

# Each running job as { path, devices, operation, progress, bytes }, progress
# null while UDisks2 cannot tell. A block object is named after its kernel
# device.
udisks_jobs() {
  call /org/freedesktop/UDisks2 org.freedesktop.DBus.ObjectManager GetManagedObjects | jq -c '[
    .data[0] | to_entries[] | .key as $path | .value["org.freedesktop.UDisks2.Job"] // empty | {
      $path,
      devices: [.Objects.data[] | "/dev/" + (split("/") | last)],
      operation: .Operation.data,
      progress: (if .ProgressValid.data then .Progress.data else null end),
      bytes: .Bytes.data
    }
  ]'
}

# The USB disks as { name, model, size, fstype, label, partitions, busy, job }:
# `busy` while a format from here runs on it, `job` while UDisks2 works on it
# or one of its partitions. A disk without a readable medium reports size 0.
list() {
  local busy=() marker
  for marker in "$runtime"/*; do
    if [[ -f $marker ]] && kill -0 "$(<"$marker")" 2>/dev/null; then
      busy+=("/dev/${marker##*/}")
    fi
  done

  lsblk -Jbpo NAME,TYPE,TRAN,SIZE,VENDOR,MODEL,FSTYPE,LABEL,MOUNTPOINTS |
    jq -c --argjson jobs "$(udisks_jobs)" '[
      .blockdevices[]
      | select(.type == "disk" and .tran == "usb" and .size > 0)
      | select(all(.. | objects | .mountpoints[]? | select(. != null); startswith("/media/")))
      | ([.name] + [.children[]?.name]) as $names
      | {
          name,
          model: ([.vendor, .model] | map(. // "" | gsub("^\\s+|\\s+$"; "")) | map(select(. != "")) | join(" ")),
          size,
          fstype,
          label,
          partitions: [.children[]? | select(.type == "part") | { name, size, fstype, label }],
          busy: (.name | IN($ARGS.positional[])),
          job: (first($jobs[] | select(any(.devices[]; IN($names[])))) // null)
        }
    ]' --args "${busy[@]}"
}

# The listed disk that is or holds the device, as `<disk> <model>`.
find_disk() {
  list | jq -r --arg device "$1" '.[] | select(.name == $device or any(.partitions[]; .name == $device)) | "\(.name) \(.model)"'
}

format() {
  # `marker` is global, for the EXIT trap.
  local device=$1 fstype=$2 label=$3 mode=$4 parttype name disk model part path options=()
  title=$device
  # No `mkfs-args` to force FAT32: UDisks2 takes them only with admin rights,
  # and mkfs.vfat picks FAT32 itself at stick sizes.
  case $fstype in
  vfat) parttype=0x0c name=FAT32 ;;
  exfat) parttype=0x07 name=exFAT ;;
  ntfs) parttype=0x07 name=NTFS ;;
  ext4) parttype=0x83 name=ext4 ;;
  *) die "cannot format as $fstype" ;;
  esac
  [[ $mode == quick || $mode == full ]] || die "quick or full, not $mode"
  read -r disk model < <(find_disk "$device") || die "$device is not a USB disk or one of its partitions"
  title=${model:-$disk}
  if [[ $device != "$disk" ]]; then
    title="${device##*/} on $title"
  fi

  mkdir -p "$runtime"
  marker=$runtime/${disk##*/}
  if [[ -f $marker ]] && kill -0 "$(<"$marker")" 2>/dev/null; then
    die "$disk is already being formatted"
  fi
  echo $$ >"$marker"
  trap 'rm -f "$marker"' EXIT

  while read -r part; do
    path=$(object "$part")
    call "$path" org.freedesktop.UDisks2.Filesystem Unmount 'a{sv}' 0 >/dev/null
  done < <(lsblk -Jpo NAME,MOUNTPOINTS "$device" | jq -r '.. | objects | select(any(.mountpoints[]?; . != null)) | .name')

  # Uppercased as UDisks2 writes a FAT label, for the notification.
  if [[ $fstype == vfat ]]; then
    label=${label^^}
  fi
  if [[ -n $label ]]; then
    options+=(label s "$label")
  fi
  if [[ $mode == full ]]; then
    options+=(erase s zero)
  fi
  if [[ $fstype == ext4 ]]; then
    options+=(take-ownership b true)
  fi

  path=$(object "$device")
  if [[ $device == "$disk" ]]; then
    call "$path" org.freedesktop.UDisks2.Block Format 'sa{sv}' dos 0 >/dev/null
    call "$path" org.freedesktop.UDisks2.PartitionTable CreatePartitionAndFormat 'ttssa{sv}sa{sv}' \
      0 0 "$parttype" "" 0 "$fstype" $((${#options[@]} / 3)) "${options[@]}" >/dev/null
  else
    options+=(update-partition-type b true)
    call "$path" org.freedesktop.UDisks2.Block Format 'sa{sv}' "$fstype" $((${#options[@]} / 3)) "${options[@]}" >/dev/null
  fi

  notify "Formatted $title" "$name${label:+, labelled $label}"
}

cancel() {
  local job
  job=$(list | jq -r --arg device "$1" '.[] | select(.name == $device or any(.partitions[]; .name == $device)) | .job.path // empty')
  [[ -n $job ]] || die "nothing to cancel on $1"
  call "$job" org.freedesktop.UDisks2.Job Cancel 'a{sv}' 0 >/dev/null
}

usage="usage: usb-format list | format <device> vfat|exfat|ntfs|ext4 <label> quick|full | cancel <device>"
case ${1:-} in
list)
  (($# == 1)) || die "$usage"
  list
  ;;
format)
  (($# == 5)) || die "$usage"
  format "$2" "$3" "$4" "$5"
  ;;
cancel)
  (($# == 2)) || die "$usage"
  cancel "$2"
  ;;
*) die "$usage" ;;
esac
