{ ... }:

{
  # TLP owns the CPU frequency governor, so a host importing this role must not
  # set `powerManagement.cpuFreqGovernor`: the two fight over the same knob.
  services.tlp.enable = true;

  # Applies on external power too, since logind ignores an unset
  # HandleLidSwitchExternalPower.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
}
