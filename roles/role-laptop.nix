{ ... }:

{
  # TLP owns the CPU frequency governor, so a host importing this role must not
  # set `powerManagement.cpuFreqGovernor`: the two fight over the same knob.
  services.tlp.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
  };
}
