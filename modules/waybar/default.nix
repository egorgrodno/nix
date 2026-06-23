{ config, lib, pkgs, forAllUsers, theme, ... }:

let
  cfg = config.my.waybar;
  borderRadius = "20px";

  waybar-network = pkgs.writeShellScriptBin "waybar-network" ''
    iface=$(${pkgs.iproute2}/bin/ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -z "$iface" ]; then
      echo "⚠ No network"
      exit 0
    fi

    rx1=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx1=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)

    sleep 1

    rx2=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx2=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)

    format_rate() {
      local bytes=$1
      if (( bytes >= 1000000000 )); then
        printf "%3d Gb/s" $(( bytes / 1000000000 ))
      elif (( bytes >= 1000000 )); then
        printf "%3d Mb/s" $(( bytes / 1000000 ))
      elif (( bytes >= 1000 )); then
        printf "%3d Kb/s" $(( bytes / 1000 ))
      else
        printf "%3d  b/s" "$bytes"
      fi
    }

    up=$(format_rate $(( tx2 - tx1 )))
    down=$(format_rate $(( rx2 - rx1 )))

    echo "󰜷 $up  󰜮 $down"
  '';

in {
  options.my.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf cfg.enable {
    home-manager.users = forAllUsers {
      programs.waybar = {
        enable = true;

        settings = [{
          layer = "top";
          position = "top";
          height = 30;
          "margin-top" = 0;
          "margin-bottom" = 0;
          spacing = 0;

          "modules-left" = [ "hyprland/window" ];
          "modules-center" = [ "hyprland/submap" "hyprland/workspaces" ];
          "modules-right" = [ "battery" "custom/network" "cpu" "memory" "disk" "pulseaudio" "tray" "clock" "custom/wlogout" ];

          "hyprland/workspaces" = {
            format = "{name}";
            "on-click" = "activate";
            width = 300;
            "persistent-only" = false;
            "format-icons" = {
              "1" = "";
              "2" = "";
              "3" = "";
              "4" = "";
              "5" = "";
              active = "";
              default = "";
            };
          };

          "hyprland/window" = {
            "max-length" = 50;
            "separate-outputs" = true;
            format = "   {title}";
          };

          tray = {
            format = "{icon} {count}";
            "icon-size" = 24;
            spacing = 10;
            "max-length" = 30;
            position = "right";
            "reverse-direction" = true;
          };

          clock = {
            interval = 1;
            timezone = "Europe/Amsterdam";
            "tooltip-format" = "{calendar}";
            format = "{:%a %b %d %Y %H:%M}";
            "format-alt" = "{:%e.%m.%Y %X}";
          };

          pulseaudio = {
            format = "{format_source}    {icon}  {volume}%";
            "format-source" = "";
            "format-source-muted" = "󰍭";
            "tooltip-format" = "{desc}";
            "format-icons" = {
              headphones = [ " " " " " " ];
              handsfree = "";
              headset = [ " " " " " " ];
              phone = [ " " " " " " ];
              portable = [ " " " " " " ];
              car = [ " " " " " " ];
              default = [ "" "" "" ];
              "default-muted" = "";
            };
            "scroll-step" = 5;
            "on-click" = "pavucontrol";
          };


          "custom/network" = {
            exec = "${waybar-network}/bin/waybar-network";
            interval = 2;
            format = "{}";
            tooltip = false;
            "on-click" = "nm-connection-editor";
          };

          cpu = {
            format = "CPU {usage}%";
            interval = 10;
          };

          memory = {
            format = "RAM {}%";
            interval = 10;
            "tooltip-format" = "Used: {percentage}%, {used:0.1f}GiB / {total:0.1f}GiB";
          };

          disk = {
            interval = 30;
            format = "DISK {percentage_used}%";
            "format-icons" = [ "" "" "" ];
            path = "/";
            tooltip = true;
            "tooltip-format" = "Free: {free}\nUsed: {percentage_used}%, {used} / {total}";
            "critical-threshold" = 90;
            "on-click" = "xdg-open /";
          };

          battery = {
            states = {
              good = 90;
              warning = 30;
              critical = 15;
            };
            format = "{icon} {capacity}%";
            "format-charging" = " {capacity}%";
            "format-plugged" = " {capacity}%";
            "format-alt" = "{time} {icon}";
            "format-icons" = [ "" "" "" "" "" ];
          };

          "custom/wlogout" = {
            format = "⏻";
            "on-click" = "${pkgs.wlogout}/bin/wlogout";
            tooltip = false;
          };
        }];

        style = ''
          @define-color border-color #5294e2;
          @define-color main-bg-color rgba(43, 48, 59, 0.3);
          @define-color main-fg-color #fff;
          @define-color module-bg-color rgba(62, 68, 82, 0.8);
          @define-color module-bg-color-hover rgba(62, 68, 82, 1);
          @define-color tooltip-bg-color #282c34;

          @define-color error #ff5555;
          @define-color disabled #a9b6c2;

          * {
            font-family: "${theme.fontUI}", monospace;
          }

          window#waybar {
            background-color: @main-bg-color;
            color: @main-fg-color;
          }

          #waybar .modules-right .module {
            background-color: @module-bg-color;
            font-size: 16px;
            transition: background-color .15s ease-out;
          }

          #waybar .modules-right .module:not(#memory):not(#disk):not(#cpu) {
            border-radius: ${borderRadius};
          }

          #waybar .module:not(#workspaces):not(#cpu):not(#disk):not(#memory) {
            padding: 5px 16px;
          }

          .module#cpu {
            padding: 5px 8px 5px 16px;
            border-top-left-radius: ${borderRadius};
            border-bottom-left-radius: ${borderRadius};
          }

          .module#memory {
            padding: 5px 8px;
          }

          .module#disk {
            padding: 5px 16px 5px 8px;
            border-top-right-radius: ${borderRadius};
            border-bottom-right-radius: ${borderRadius};
          }

          .module#tray > .passive {
            -gtk-icon-effect: dim;
          }

          .module#tray:hover,
          .module#pulseaudio:hover,
          .module#custom-network:hover,
          .module#disk:hover,
          .module#clock:hover,
          .module#custom-wlogout:hover
          {
            background-color: @module-bg-color-hover;
          }

          #waybar > box {
            margin: 8px 20px;
          }

          #waybar .modules-center .module {
            margin: 0 6px;
          }

          #waybar .modules-left .module {
            margin-right: 12px;
            color: #fff;
            text-shadow: 0px 1px 4px rgba(0, 0, 0, 0.7);
          }

          #waybar .modules-right .module:not(#memory):not(#disk) {
            margin-left: 12px;
          }

          tooltip {
            background: @tooltip-bg-color;
            border: 2px solid @border-color;
            border-radius: ${borderRadius};
            opacity: 0.95;
          }

          tooltip label {
            padding: 8px;
          }

          #workspaces button {
            color: @main-fg-color;
            transition: color .15s ease-out, background-color .15s ease-out;
            padding: 0px 16px;
            border-radius: ${borderRadius};
          }

          #workspaces button:hover {
            background-color: rgba(255, 255, 255, 0.08);
          }

          #workspaces button.active {
            background-color: rgba(255, 255, 255, 0.08);
          }

          #workspaces button.urgent {
            color: @main-fg-color;
            background-color: @error;
          }

          #workspaces button.urgent:hover {
            color: @main-fg-color;
            background-color: @error;
          }

          #workspaces button.empty {
            color: @disabled;
          }

          #disk.critical {
            color: @error;
          }


          #custom-wlogout {
            color: #E06C75;
          }

          #custom-wlogout:hover {
            color: #fff;
            background-color: rgba(224, 108, 117, 0.5);
          }
        '';
      };
    };
  };
}
