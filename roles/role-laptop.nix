{ ... }:

{
  imports = [ ../modules/power ];

  my.power.enable = true;

  # Applies on external power too, since logind ignores an unset
  # HandleLidSwitchExternalPower.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
}
