# Installs NixOS from this flake, from a NixOS ISO booted in UEFI mode. Every
# question is asked, and the configuration evaluated, before any disk is
# touched.
#
# Usage: install [repository], which defaults to the GitHub repository.

repo=${1:-https://github.com/egorgrodno/nix.git}
mnt=/mnt
work=$(mktemp -d)
clone=$work/nix
mounted=()

# Partition type GUIDs, as blkid reports them.
espType=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
msReservedType=e3c9e316-0b5c-4db8-817d-f92df00215ae

die() {
  echo "install: $*" >&2
  exit 1
}

cleanup() {
  for ((i = ${#mounted[@]} - 1; i >= 0; i--)); do
    umount "${mounted[i]}" || true
  done
  rm -rf "$work"
}
trap cleanup EXIT

nixf() {
  nix --extra-experimental-features 'nix-command flakes' --option warn-dirty false "$@"
}

isAdmin() {
  [[ $(nixf eval --impure --expr "(import $clone/users/$1.nix).admin or false") == true ]]
}

# The first device carrying the label, which must be the only one.
onlyLabelled() {
  local devices
  mapfile -t devices < <(blkid -c /dev/null -o device -t "LABEL=$1" || true)
  ((${#devices[@]} == 1)) || die "expected one partition labelled $1, found ${#devices[@]}"
  echo "${devices[0]}"
}

connectedScreen() {
  local status name first=""
  for status in /sys/class/drm/card*-*/status; do
    [[ -e $status ]] || continue
    [[ $(<"$status") == connected ]] || continue
    name=${status%/status}
    name=${name##*/}
    name=${name#card*-}
    [[ $name == eDP-* ]] && echo "$name" && return
    first=${first:-$name}
  done
  echo "${first:-eDP-1}"
}

askNewHost() {
  host=$(gum input --header "Hostname of the new host")
  [[ $host =~ ^[a-z][a-z0-9-]*$ ]] || die "a hostname is lowercase letters, digits and dashes"
  [[ ! -e $clone/hosts/$host ]] || die "hosts/$host exists; reinstall it instead"

  layout=$(gum choose --header "Keyboard layout" qwerty hallmack)
  if gum confirm "Swap Caps Lock and Escape?"; then swapCaps=true; else swapCaps=false; fi

  case $(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true) in
  8 | 9 | 10 | 11 | 14 | 30 | 31 | 32) form=laptop ;;
  *) form=pc ;;
  esac
  form=$(gum choose --header "Form factor" --selected "$form" laptop pc)
  if gum confirm "Hibernate? It takes a swapfile the size of RAM."; then hibernate=true; else hibernate=false; fi

  cpu=amd
  grep -q GenuineIntel /proc/cpuinfo && cpu=intel
  cpu=$(gum choose --header "CPU vendor" --selected "$cpu" amd intel)

  local vendors
  vendors=$(lspci -mmn | awk '$2 ~ /^"03/ { gsub(/"/, "", $3); print $3 }')
  gpu=amd
  grep -q 8086 <<<"$vendors" && gpu=intel
  grep -q 10de <<<"$vendors" && gpu=nvidia
  gpu=$(gum choose --header "GPU vendor" --selected "$gpu" amd intel nvidia)

  screen=$(gum input --header "Primary screen connector" --value "$(connectedScreen)")

  local all
  mapfile -t all < <(find "$clone/users" -name '*.nix' -printf '%f\n' | sed 's/\.nix$//' | sort)
  mapfile -t users < <(gum choose --no-limit --header "Users (space selects, enter confirms)" "${all[@]}")
}

writeHost() {
  local dir=$clone/hosts/$host release memKb swapGib
  mkdir -p "$dir"
  release=$(nixf eval --raw --inputs-from "$clone" nixpkgs#lib.trivial.release)

  cat >"$dir/host.nix" <<EOF
# Data only, rewritten by the installer: names from users/ and the release the
# disk was installed with.
{
  users = [ $(printf '"%s" ' "${users[@]}")];
  stateVersion = "$release";
}
EOF

  nixos-generate-config --show-hardware-config --no-filesystems >"$dir/hardware-configuration.nix"

  if [[ $isNew == true ]]; then
    memKb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    swapGib=$(((memKb + 1048575) / 1048576))
    writeConfiguration "$dir/configuration.nix"
  fi

  nixfmt "$dir"/*.nix
  git -C "$clone" add "hosts/$host"
}

writeConfiguration() {
  {
    cat <<'EOF'
{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../roles/role-desktop-config.nix
  ];
EOF
    [[ $form == pc ]] || printf '\n  base.isLaptop = true;\n'
    cat <<EOF

  base.keyboard = {
    layout = "$layout";
    swapCapsEscape = $swapCaps;
  };

  my.desktop.primaryScreen = "$screen";

  hardware.enableRedistributableFirmware = true;
EOF
    [[ $cpu == amd ]] || echo '  services.thermald.enable = true;'
    case $gpu in
    intel) echo '  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];' ;;
    nvidia)
      cat <<'EOF'

  # `open` needs a Turing or newer card. powerManagement saves video memory
  # across the suspend, or hibernation, the desktop module triggers on idle.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
  };
  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
EOF
      ;;
    esac
    cat <<EOF

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };
  };
EOF
    [[ $hibernate == false ]] || cat <<EOF

  base.hibernate = true;

  # Sized to RAM so any workload fits the hibernation image. systemd records the
  # file's location in the HibernateLocation EFI variable and the systemd initrd
  # resumes from it, so neither \`resume=\` nor \`resume_offset=\` is set.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = $swapGib * 1024;
    }
  ];
EOF
    cat <<'EOF'

  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    # Keyboard-interactive goes through PAM, which prompts for the same password.
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
EOF
  } >"$1"
}

askWipe() {
  local isoDisk="" medium lines choice part fstype ptype label device windows=()
  # The live medium: a partition on a disk, or a whole USB stick or CD.
  if medium=$(findmnt -no SOURCE /iso); then
    isoDisk=$(lsblk -dnpo PKNAME "$medium")
    isoDisk=${isoDisk:-$medium}
  fi
  mapfile -t lines < <(lsblk -dnpo NAME,TYPE,SIZE,MODEL | awk -v iso="$isoDisk" '$2 == "disk" && $1 != iso { line = $1; for (i = 3; i <= NF; i++) line = line " " $i; print line }')
  ((${#lines[@]})) || die "no disk to install to"
  choice=$(gum choose --header "Disk to wipe" "${lines[@]}")
  disk=${choice%% *}
  diskInfo=$choice

  [[ -z $(lsblk -nro MOUNTPOINTS "$disk") ]] || die "$disk has mounted partitions"

  # Two partitions with one of these labels would make the by-label mounts of
  # the installed system ambiguous.
  for label in NIXROOT NIXBOOT; do
    while read -r device; do
      [[ $(lsblk -npo PKNAME "$device") == "$disk" ]] ||
        die "$device elsewhere is labelled $label; relabel or wipe it first"
    done < <(blkid -c /dev/null -o device -t "LABEL=$label" || true)
  done

  mkdir -p "$work/esp"
  while read -r part; do
    fstype=$(blkid -p -s TYPE -o value "$part" || true)
    ptype=$(blkid -p -s PART_ENTRY_TYPE -o value "$part" || true)
    [[ $fstype == ntfs ]] && windows+=("$part holds NTFS")
    [[ $ptype == "$msReservedType" ]] && windows+=("$part is a Microsoft reserved partition")
    if [[ $ptype == "$espType" ]] && mount -o ro "$part" "$work/esp" 2>/dev/null; then
      [[ -d $work/esp/EFI/Microsoft ]] && windows+=("$part holds the Windows bootloader")
      umount "$work/esp"
    fi
  done < <(lsblk -lnpo NAME,TYPE "$disk" | awk '$2 == "part" { print $1 }')

  if ((${#windows[@]})); then
    printf '  %s\n' "${windows[@]}"
    [[ $(gum input --header "Windows is on $disk. Type $disk to wipe it anyway") == "$disk" ]] ||
      die "left $disk alone"
  fi
}

askReuse() {
  root=$(onlyLabelled NIXROOT)
  boot=$(onlyLabelled NIXBOOT)
  [[ $(blkid -p -s TYPE -o value "$boot" || true) == vfat ]] || die "$boot is labelled NIXBOOT but is not FAT"
  [[ -z $(lsblk -nro MOUNTPOINTS "$root" "$boot") ]] || die "$root or $boot is mounted"
}

wipe() {
  local prefix=$disk
  [[ $disk == *[0-9] ]] && prefix=${disk}p
  boot=${prefix}1
  root=${prefix}2
  sgdisk --zap-all "$disk"
  sgdisk -n 1:0:+1G -t 1:EF00 -c 1:NIXBOOT -n 2:0:0 -t 2:8300 -c 2:NIXROOT "$disk"
  udevadm settle
  # The new partitions can start where old ones did, signatures included.
  wipefs -a "$boot" "$root"
  mkfs.fat -F 32 -n NIXBOOT "$boot"
  mkfs.ext4 -F -L NIXROOT "$root"
}

[[ $EUID -eq 0 ]] || die "must run as root"
[[ -d /sys/firmware/efi ]] || die "the ISO booted in legacy BIOS mode; boot it in UEFI mode"
! mountpoint -q "$mnt" || die "$mnt is in use"

git clone --quiet "$repo" "$clone"

mapfile -t hosts < <(find "$clone/hosts" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
choice=$(gum choose --header "Host" "${hosts[@]/#/reinstall }" "new host")
if [[ $choice == "new host" ]]; then
  isNew=true
  askNewHost
else
  isNew=false
  host=${choice#reinstall }
  mapfile -t users < <(nixf eval --json --file "$clone/hosts/$host/host.nix" users | jq -r '.[]')
fi
((${#users[@]})) || die "a host needs at least one user"

admin=
for u in "${users[@]}"; do
  if isAdmin "$u"; then
    admin=$u
    break
  fi
done
[[ -n $admin ]] || die "none of ${users[*]} is an admin, so nobody could sudo"

authorName=$(gum input --header "Author name of the install commit" --value "$(git -C "$clone" log -1 --format=%an)")
authorEmail=$(gum input --header "Author email of the install commit" --value "$(git -C "$clone" log -1 --format=%ae)")

writeHost
echo "Evaluating $host..."
nixf eval --raw "$clone#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null

mode=$(gum choose --header "Disk" "wipe a disk" "reuse NIXROOT and NIXBOOT")
if [[ $mode == "wipe a disk" ]]; then
  askWipe
  plan="wipe $diskInfo: 1 GiB NIXBOOT, the rest NIXROOT"
else
  askReuse
  plan="reformat $root (NIXROOT), keep $boot (NIXBOOT) as it is"
fi

gum style --border normal --padding "0 1" \
  "$([[ $isNew == true ]] && echo "new host" || echo "reinstall") $host" \
  "users: ${users[*]} (admin: $admin)" \
  "$plan"
[[ $(gum input --header "Type $host to install") == "$host" ]] || die "nothing was touched"

if [[ $mode == "wipe a disk" ]]; then
  wipe
else
  mkfs.ext4 -F -L NIXROOT "$root"
fi

# Typed: right after mkfs the probe can come back empty, and mount then tries
# only the filesystems already loaded, which on the ISO excludes ext4.
mount -t ext4 "$root" "$mnt"
mounted+=("$mnt")
mount --mkdir -t vfat -o umask=077 "$boot" "$mnt/boot"
mounted+=("$mnt/boot")

mkdir -p "$mnt/etc"
cp -a "$clone" "$mnt/etc/nixos"
if [[ $isNew == true ]]; then message="add the $host host"; else message="reinstall $host"; fi
git -C "$mnt/etc/nixos" -c user.name="$authorName" -c user.email="$authorEmail" commit --quiet -m "$message"

nixos-install --flake "$mnt/etc/nixos#$host" --no-root-passwd --no-channel-copy

for u in "${users[@]}"; do
  echo "Password for $u"
  until nixos-enter --root "$mnt" -c "passwd $u"; do :; done
done
nixos-enter --root "$mnt" -c "chown -R $admin:users /etc/nixos"

echo "install: done, remove the ISO and reboot"
