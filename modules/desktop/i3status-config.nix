{ theme }:

''
general {
  colors = true
  color_good = "${theme.green}"
  color_degraded = "${theme.yellow}"
  color_bad = "${theme.red}"
  interval = 5
}

order += "wireless _first_"
order += "ethernet _first_"
order += "battery all"
order += "disk /"
order += "load"
order += "memory"
order += "tztime local"

wireless _first_ {
  format_up = " W: %ip (%essid) "
  format_down = " W: down "
}

ethernet _first_ {
  format_up = " E: %ip (%speed) "
  format_down = " E: down "
}

battery all {
  format = " %status %percentage %remaining "
  format_down = " No battery "
}

disk "/" {
  format = " DISK %used / %total "
}

load {
  format = " CPU %1min "
}

memory {
  format = " RAM %used / %total "
  threshold_degraded = "2G"
  format_degraded = " RAM LEFT < %available "
}

tztime local {
  format = " %d.%m.%Y %H:%M "
}
''
