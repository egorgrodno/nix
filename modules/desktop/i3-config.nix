{ config, pkgs, theme, primaryScreen }:

''
# Autostart applications
exec --no-startup-id ${pkgs.picom}/bin/picom -b
exec --no-startup-id ${pkgs.pasystray}/bin/pasystray
exec --no-startup-id ${pkgs.networkmanagerapplet}/bin/nm-applet

set $mod Mod1

default_border pixel 3
default_floating_border pixel 2

hide_edge_borders none

font xft:${theme.fontFamily} 13

# Disable for blender
floating_modifier $mod

bindsym $mod+Return exec --no-startup-id i3-sensible-terminal

bindsym $mod+Escape kill

bindsym $mod+d exec "dmenu-history -p ' λ '"

${if config.services.pipewire.enable then ''
bindsym XF86AudioMute exec --no-startup-id "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && notify-volume"
bindsym XF86AudioLowerVolume exec --no-startup-id "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && notify-volume"
bindsym XF86AudioRaiseVolume exec --no-startup-id "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && notify-volumn"
'' else ""}

bindsym $mod+F2 exec ${pkgs.galculator}/bin/galculator
bindsym $mod+F3 exec ${pkgs.pcmanfm}/bin/pcmanfm
bindsym $mod+F4 exec ${pkgs.transmission_4-gtk}/bin/transmission-gtk
bindsym $mod+F5 exec ${pkgs.simplescreenrecorder}/bin/simplescreenrecorder
bindsym $mod+F6 exec ${pkgs.glances}/bin/glances
bindsym Print exec --no-startup-id ${pkgs.shutter}/bin/shutter
bindsym $mod+Ctrl+x --release exec --no-startup-id ${pkgs.xorg.xkill}/bin/xkill
bindsym $mod+Ctrl+m exec --no-startup-id ${pkgs.pavucontrol}/bin/pavucontrol

${if config.base.keyboard.layout == "hallmack" then ''
bindsym $mod+g focus left
bindsym $mod+a focus down
bindsym $mod+e focus up
bindsym $mod+o focus right

bindsym $mod+Shift+g move left
bindsym $mod+Shift+a move down
bindsym $mod+Shift+e move up
bindsym $mod+Shift+o move right
'' else ''
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right
''}

bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# workspace back and forth (with/without active container)
workspace_auto_back_and_forth yes
bindsym $mod+b workspace back_and_forth
bindsym $mod+Shift+b move container to workspace back_and_forth; workspace back_and_forth

${if config.base.keyboard.layout == "hallmack" then ''
bindsym $mod+h split h;exec notify-send -u low 'tile horizontally'
'' else ''
bindsym $mod+z split h;exec notify-send -u low 'tile horizontally'
''}
bindsym $mod+v split v;exec notify-send -u low 'tile vertically'
bindsym $mod+q exec i3kill

bindsym $mod+f fullscreen toggle

# change container layout (stacked, tabbed, toggle split)
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
${if config.base.keyboard.layout == "hallmack" then ''
bindsym $mod+l layout toggle split
'' else ''
bindsym $mod+e layout toggle split
''}

bindsym $mod+Shift+space floating toggle

bindsym $mod+space focus mode_toggle

# toggle sticky
bindsym $mod+Shift+s sticky toggle

# focus the parent container
${if config.base.keyboard.layout == "hallmack" then ''
bindsym $mod+p focus parent
'' else ''
bindsym $mod+a focus parent
''}

# move the currently focused window to the scratchpad
bindsym $mod+Shift+minus move scratchpad

# cycle through scratchpad windows
bindsym $mod+minus scratchpad show

# workspace names
set $ws1 1
set $ws2 2
set $ws3 3
set $ws4 4
set $ws5 5
set $ws6 6
set $ws7 7
set $ws8 8
set $ws9 9

# check the class `xprop | grep WM_CLASS`
for_window [class="*"] floating enable
for_window [class=".*"] floating enable
for_window [class="^st-*"] floating disable
for_window [class="^Chromium-browser$"] floating disable
for_window [class="^telegram-desktop$"] floating disable
for_window [class="^Galculator$"] sticky enable
for_window [class="^Pcmanfm$"] resize set 1300 1100
for_window [class="^Slack$"] floating disable
assign [class="^Slack$"] $ws3

# switch to workspace
bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3
bindsym $mod+4 workspace $ws4
bindsym $mod+5 workspace $ws5
bindsym $mod+6 workspace $ws6
bindsym $mod+7 workspace $ws7
bindsym $mod+8 workspace $ws8
bindsym $mod+9 workspace $ws9

# Move focused container to workspace
bindsym $mod+Ctrl+1 move container to workspace $ws1
bindsym $mod+Ctrl+2 move container to workspace $ws2
bindsym $mod+Ctrl+3 move container to workspace $ws3
bindsym $mod+Ctrl+4 move container to workspace $ws4
bindsym $mod+Ctrl+5 move container to workspace $ws5
bindsym $mod+Ctrl+6 move container to workspace $ws6
bindsym $mod+Ctrl+7 move container to workspace $ws7
bindsym $mod+Ctrl+8 move container to workspace $ws8
bindsym $mod+Ctrl+9 move container to workspace $ws9

# Move to workspace with focused container
bindsym $mod+Shift+1 move container to workspace $ws1; workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2; workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3; workspace $ws3
bindsym $mod+Shift+4 move container to workspace $ws4; workspace $ws4
bindsym $mod+Shift+5 move container to workspace $ws5; workspace $ws5
bindsym $mod+Shift+6 move container to workspace $ws6; workspace $ws6
bindsym $mod+Shift+7 move container to workspace $ws7; workspace $ws7
bindsym $mod+Shift+8 move container to workspace $ws8; workspace $ws8
bindsym $mod+Shift+9 move container to workspace $ws9; workspace $ws9

# reload the configuration file
bindsym $mod+Shift+c reload

# restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
bindsym $mod+Shift+r restart

# exit i3 (logs you out of your X session)
${if config.base.keyboard.layout == "hallmack" then ''
bindsym $mod+Shift+q exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"
'' else ''
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"
''}

# Set shut down, restart and locking features
bindsym $mod+0 mode "$mode_system"
set $mode_system (l)ock, (h)ibernate, (r)eboot, (s)uspend, (Shift+s)hutdown
mode "$mode_system" {
  bindsym h exec --no-startup-id i3exit hibernate, mode "default"
  bindsym r exec --no-startup-id i3exit reboot, mode "default"
  bindsym l exec --no-startup-id i3exit lock, mode "default"
  bindsym s exec --no-startup-id i3exit suspend, mode "default"
  bindsym Shift+s exec --no-startup-id i3exit shutdown, mode "default"

  bindsym Return mode "default"
  bindsym Escape mode "default"
}

# Resize window (you can also use the mouse for that)
bindsym $mod+r mode "resize"
mode "resize" {
  ${if config.base.keyboard.layout == "hallmack" then ''
  bindsym g resize shrink width 5 px or 5 ppt
  bindsym a resize grow height 5 px or 5 ppt
  bindsym e resize shrink height 5 px or 5 ppt
  bindsym o resize grow width 5 px or 5 ppt
  '' else ''
  bindsym h resize shrink width 5 px or 5 ppt
  bindsym j resize grow height 5 px or 5 ppt
  bindsym k resize shrink height 5 px or 5 ppt
  bindsym l resize grow width 5 px or 5 ppt
  ''}

  bindsym Left resize shrink width 10 px or 10 ppt
  bindsym Down resize grow height 10 px or 10 ppt
  bindsym Up resize shrink height 10 px or 10 ppt
  bindsym Right resize grow width 10 px or 10 ppt

  bindsym Return mode "default"
  bindsym Escape mode "default"
}

# Start i3bar to display a workspace bar (plus the system information i3status if available)
bar {
  i3bar_command i3bar
  status_command i3status
  tray_output ${primaryScreen}
  position bottom

  bindsym button4 nop
  bindsym button5 nop
  strip_workspace_numbers yes
  tray_padding 3

  colors {
    background ${theme.background.light}
    statusline ${theme.foreground.main}
    separator  ${theme.foreground.dark}

    focused_workspace  ${theme.blue}            ${theme.background.main} ${theme.foreground.main}
    active_workspace   ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.main}
    inactive_workspace ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.main}
    urgent_workspace   ${theme.red}             ${theme.background.main} ${theme.foreground.main}
    binding_mode       ${theme.red}             ${theme.background.main} ${theme.foreground.main}
  }
}

# Hide/show i3status bar
bindsym $mod+m bar mode toggle

#                       border                   background               foreground               indicator                child_border
client.focused          ${theme.blue}            ${theme.background.main} ${theme.foreground.main} ${theme.green}           ${theme.blue}
client.focused_inactive ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.main} ${theme.foreground.dark} ${theme.foreground.dark}
client.unfocused        ${theme.foreground.dark} ${theme.background.main} ${theme.foreground.dark} ${theme.foreground.dark} ${theme.foreground.dark}
client.urgent           ${theme.red}             ${theme.background.main} ${theme.red}             ${theme.green}           ${theme.red}
client.placeholder      ${theme.background.main} ${theme.background.main} ${theme.foreground.dark} ${theme.foreground.dark} ${theme.background.main}

client.background       ${theme.background.main}

# Set inner/outer gaps
gaps inner 12
gaps outer 0

# Draw gaps if not the only container
smart_gaps on

# Draw borders if not the only container
smart_borders on

include $XDG_CONFIG_HOME/i3/user-configuration.conf
''
