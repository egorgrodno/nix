# What the bar's stats read but cannot list from QML, as tab-separated lines:
# `hardware` once at start, the rest while a tooltip is open.

# A cgroup's app: its unit without escapes, instance, a scope's random suffix,
# and the `app-` and desktop prefixes uwsm adds, so every scope of one app
# shares a key. A `wayland-wm@<id>.desktop` unit is its compositor.
key_awk='
function key(path,   unit, inst) {
  unit = path
  sub(/.*\//, "", unit)
  gsub(/\\x2d/, "-", unit)
  if (unit ~ /\.scope$/) {
    sub(/\.scope$/, "", unit)
    sub(/(-[0-9a-f]+)+$/, "", unit)
  } else
    sub(/\.[a-z]+$/, "", unit)
  if (unit ~ /@/) {
    inst = unit
    sub(/^[^@]*@/, "", inst)
    sub(/@.*/, "", unit)
    if (inst ~ /\.desktop$/) {
      unit = inst
      sub(/\.desktop$/, "", unit)
    }
  }
  sub(/^app-/, "", unit)
  if (desktop != "" && index(unit, desktop "-") == 1)
    unit = substr(unit, length(desktop) + 2)
  return unit
}
function cgroup(pid,   line, path) {
  path = ""
  while ((getline line < ("/proc/" pid "/cgroup")) > 0)
    if (line ~ /^0::/)
      path = substr(line, 4)
  close("/proc/" pid "/cgroup")
  return path
}
'
desktop=${XDG_CURRENT_DESKTOP%%:*}

# The sensors, GPUs and memory modules:
#   cpu-temp <path>, dimm-temp <path>, disk-temp <disk> <path>
#   gpu <pci> <driver> <integrated 0|1> <model>
#   gpu-file <pci> <name> <path>, the first of a name the one to read
#   connector <pci> <status path>
#   memory <udev property>=<value>
hardware() {
  for h in /sys/class/hwmon/hwmon*; do
    case $(cat "$h/name") in
    k10temp | zenpower | coretemp) echo "cpu-temp	$h/temp1_input" ;;
    spd5118 | jc42) echo "dimm-temp	$h/temp1_input" ;;
    esac
  done
  for b in /sys/block/*; do
    for t in "$b"/device/hwmon*/temp1_input "$b"/device/hwmon/hwmon*/temp1_input; do
      if [ -e "$t" ]; then echo "disk-temp	${b##*/}	$t"; fi
    done
  done
  for c in /sys/class/drm/card[0-9]*; do
    case ${c##*/} in *-*) continue ;; esac
    d=$(readlink -f "$c/device")
    pci=${d##*/}
    hwmon=$(echo "$d"/hwmon/hwmon*)
    # amdgpu shows the northbridge voltage only on an APU.
    integrated=0
    if [ "$(cat "$hwmon/in1_label" 2>/dev/null)" = vddnb ]; then integrated=1; fi
    model=$(udevadm info -q property -p "$d" | sed -n 's/^ID_MODEL_FROM_DATABASE=//p')
    echo "gpu	$pci	$(basename "$(readlink -f "$d/driver")")	$integrated	$model"
    for f in busy:$d/gpu_busy_percent video:$d/vcn_busy_percent \
      vramUsed:$d/mem_info_vram_used vramTotal:$d/mem_info_vram_total \
      gttUsed:$d/mem_info_gtt_used gttTotal:$d/mem_info_gtt_total \
      temp:$hwmon/temp1_input hotspot:$hwmon/temp2_input \
      power:$hwmon/power1_average power:$hwmon/power1_input \
      powerCap:$hwmon/power1_cap clock:$hwmon/freq1_input fan:$hwmon/fan1_input; do
      if [ -e "${f#*:}" ]; then echo "gpu-file	$pci	${f%%:*}	${f#*:}"; fi
    done
    for s in "$c"-*/status; do
      if [ -e "$s" ]; then echo "connector	$pci	$s"; fi
    done
  done
  udevadm info -q property -p /sys/class/dmi/id | sed -n 's/^MEMORY_DEVICE_/memory	&/p'
}

# Each leaf cgroup: <app> <cpu usage µs> <anonymous and shared memory bytes>.
apps() {
  find /sys/fs/cgroup -mindepth 1 -type d -links 2 | awk -v desktop="$desktop" "$key_awk"'
  {
    cpu = mem = 0
    while ((getline line < ($0 "/cpu.stat")) > 0)
      if (split(line, f, " ") == 2 && f[1] == "usage_usec")
        cpu = f[2]
    close($0 "/cpu.stat")
    while ((getline line < ($0 "/memory.stat")) > 0)
      if (split(line, f, " ") == 2 && (f[1] == "anon" || f[1] == "shmem"))
        mem += f[2]
    close($0 "/memory.stat")
    print key($0) "\t" cpu "\t" mem
  }'
}

# Each DRM client of the user's, once however many descriptors share it:
# <pci> <app> <client id> <gfx and compute ns> <vram bytes> <gtt bytes>.
drm_clients() {
  { find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/dri/*' 2>/dev/null || :; } |
    awk -v desktop="$desktop" "$key_awk"'
    function bytes(v) {
      if (v ~ /KiB/) return v * 1024
      if (v ~ /MiB/) return v * 1048576
      if (v ~ /GiB/) return v * 1073741824
      return v + 0
    }
    {
      file = $0
      sub(/\/fd\//, "/fdinfo/", file)
      pid = $0
      sub(/^\/proc\//, "", pid)
      sub(/\/.*/, "", pid)
      pdev = client = ""
      engine = 0
      split("", resident)
      split("", memory)
      while ((getline line < file) > 0) {
        split(line, f, /:[ \t]+/)
        if (f[1] == "drm-pdev") pdev = f[2]
        else if (f[1] == "drm-client-id") client = f[2]
        else if (f[1] == "drm-engine-gfx" || f[1] == "drm-engine-compute") engine += f[2]
        else if (f[1] ~ /^drm-resident-(vram|gtt)$/) resident[substr(f[1], 14)] = bytes(f[2])
        else if (f[1] ~ /^drm-memory-(vram|gtt)$/) memory[substr(f[1], 12)] = bytes(f[2])
      }
      close(file)
      if (client == "" || seen[pdev, client]++)
        next
      vram = ("vram" in resident) ? resident["vram"] : memory["vram"] + 0
      gtt = ("gtt" in resident) ? resident["gtt"] : memory["gtt"] + 0
      print pdev "\t" key(cgroup(pid)) "\t" client "\t" engine "\t" vram "\t" gtt
    }'
}

# Each process on an NVIDIA GPU, over a second: <gpu index> <app> <pid> <sm %>
# <memory MiB>. pmon names its columns in its first comment line.
nvidia_clients() {
  nvidia-smi pmon -c 1 -s um | awk -v desktop="$desktop" "$key_awk"'
    /^# *gpu/ {
      for (i = 2; i <= NF; i++)
        col[$i] = i - 1
      next
    }
    /^#/ || $col["pid"] !~ /^[0-9]+$/ { next }
    {
      sm = $col["sm"]
      fb = $col["fb"]
      print $col["gpu"] "\t" key(cgroup($col["pid"])) "\t" $col["pid"] "\t" sm + 0 "\t" fb + 0
    }'
}

# Each system generation: <number> <creation time>.
generations() {
  for l in /nix/var/nix/profiles/system-*-link; do
    n=${l##*/system-}
    echo "${n%-link}	$(stat -c %Y "$l")"
  done
}

case ${1:-} in
hardware) hardware ;;
apps) apps ;;
drm-clients) drm_clients ;;
nvidia-clients) nvidia_clients ;;
generations) generations ;;
*)
  echo "usage: stats-probe hardware|apps|drm-clients|nvidia-clients|generations" >&2
  exit 2
  ;;
esac
