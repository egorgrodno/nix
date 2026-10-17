{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.power;
  tlp = config.services.tlp.package;

  # The thinkpad's supply names.
  ac = "/sys/class/power_supply/AC";
  batteryName = "BAT0";
  battery = "/sys/class/power_supply/${batteryName}";

  # At or below this charge, running on battery selects power-saver.
  lowBattery = 20;

  # TLP_AUTO_SWITCH=0 leaves the profile choice here. A change of power source
  # resets it: performance on AC, balanced or power-saver on battery by charge.
  # Discharging through lowBattery selects power-saver once per discharge.
  # Anything else keeps the profile, so a manual choice holds until the next
  # plug event.
  powerProfileSync = pkgs.writeShellApplication {
    name = "power-profile-sync";
    runtimeInputs = [
      tlp
      pkgs.coreutils
    ];
    text = ''
      state=/run/power-profile
      online=$(cat ${ac}/online)
      capacity=$(cat ${battery}/capacity)
      last=$(cat "$state/online" 2>/dev/null || echo unknown)

      if [ "$online" != "$last" ]; then
        rm -f "$state/low"
        if [ "$online" = 1 ]; then
          tlp performance
        elif [ "$capacity" -le ${toString lowBattery} ]; then
          tlp power-saver
          touch "$state/low"
        else
          tlp balanced
        fi
        # Written last, so a failed switch is retried on the next run.
        echo "$online" > "$state/online"
      elif [ "$online" = 0 ] && [ "$capacity" -le ${toString lowBattery} ] && [ ! -e "$state/low" ]; then
        tlp power-saver
        touch "$state/low"
      fi
    '';
  };

  chargeLimit = pkgs.writeShellApplication {
    name = "charge-limit";
    runtimeInputs = [
      tlp
      pkgs.coreutils
      config.systemd.package
    ];
    text = ''
      # The limit is on unless this file exists, so a fresh install starts
      # limited. Off restores the ThinkPad's factory 0/100.
      off=/var/lib/charge-limit/off

      apply() {
        if [ -e "$off" ]; then
          tlp setcharge 0 100 ${batteryName}
        else
          tlp setcharge 75 80 ${batteryName}
        fi
      }

      case "''${1:-status}" in
        status)
          if [ -e "$off" ]; then echo off; else echo on; fi
          ;;
        on | off)
          # The polkit rule below lets the session start these two units.
          if [ "$(id -u)" != 0 ]; then
            exec systemctl start "charge-limit@$1.service"
          fi
          if [ "$1" = on ]; then
            rm -f "$off"
          else
            mkdir -p "$(dirname "$off")"
            touch "$off"
          fi
          apply
          ;;
        apply)
          apply
          ;;
        *)
          echo "usage: charge-limit [status|on|off|apply]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # systemd-sleep reads its configuration when it starts, so the drop-in is
  # decided here from the profile TLP last applied, whoever chose it. The first
  # field of last_pwr is that profile, 2 for power-saver.
  hibernateDelay = pkgs.writeShellScript "hibernate-delay" ''
    dropin=/run/systemd/sleep.conf.d/power-saver.conf
    read -r profile _ < /run/tlp/last_pwr || profile=
    if [ "$profile" = 2 ]; then
      ${pkgs.coreutils}/bin/mkdir -p "''${dropin%/*}"
      printf '[Sleep]\nHibernateDelaySec=5min\n' > "$dropin"
    else
      ${pkgs.coreutils}/bin/rm -f "$dropin"
    fi
  '';

in
{
  options.my.power.enable = lib.mkEnableOption "TLP power profiles, profile switching and the battery charge limit";

  config = lib.mkIf cfg.enable {
    # TLP owns the CPU frequency governor, so a host enabling this must not set
    # `powerManagement.cpuFreqGovernor`: the two fight over the same knob.
    services.tlp = {
      enable = true;
      pd.enable = true;
      # TLP leaves a feature alone when the new profile's parameter is unset,
      # so a value one profile changes must be set in the others too. Power-saver
      # falls back to the _BAT value. amd-pstate-epp pins EPP to `performance`
      # under the performance governor, so EPP follows only once the governor
      # is back to powersave.
      settings = {
        TLP_AUTO_SWITCH = 0;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 1;
        CPU_BOOST_ON_SAV = 0;
      };
    };

    services.upower.enable = true;

    environment.systemPackages = [ chargeLimit ];

    services.udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="power_supply", RUN+="${config.systemd.package}/bin/systemctl start --no-block power-profile-sync.service"
    '';

    # tlp.service runs after multi-user.target, so a unit ordered after it must
    # hang off it rather than a target. `tlp init start` resets the profile by
    # power source, so the sync forgets the last source and decides afresh.
    systemd.services.tlp.serviceConfig.ExecStartPost =
      "${pkgs.coreutils}/bin/rm -f /run/power-profile/online";

    systemd.services.power-profile-sync = {
      description = "Select the power profile for the power source and charge";
      after = [ "tlp.service" ];
      wantedBy = [ "tlp.service" ];
      # A plug event raises about three uevents, so the default limit of five
      # starts in 10 s would drop the second of two quick plug events.
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe powerProfileSync;
        RuntimeDirectory = "power-profile";
        RuntimeDirectoryPreserve = true;
      };
    };

    # Catches the discharge through lowBattery between power_supply events.
    systemd.timers.power-profile-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "minutely";
    };

    systemd.services.charge-limit = {
      description = "Apply the battery charge limit";
      after = [ "tlp.service" ];
      wantedBy = [ "tlp.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe chargeLimit} apply";
        StateDirectory = "charge-limit";
      };
    };

    systemd.services."charge-limit@" = {
      description = "Turn the battery charge limit %i";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe chargeLimit} %i";
        StateDirectory = "charge-limit";
      };
    };

    # An active local session toggles the limit without sudo, through the two
    # charge-limit@ instances and nothing else.
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("verb") == "start" &&
            /^charge-limit@(on|off)\.service$/.test(action.lookup("unit")) &&
            subject.active && subject.local) {
          return polkit.Result.YES;
        }
      });
    '';

    # `-`: a failure here must never block the suspend.
    systemd.services.systemd-suspend-then-hibernate.serviceConfig.ExecStartPre = "-${hibernateDelay}";
  };
}
