{ config, lib, ... }:

{
  imports = [ ../modules/power ];

  config = lib.mkIf config.base.isLaptop {
    my.power.enable = true;

    # Applies on external power too, since logind ignores an unset
    # HandleLidSwitchExternalPower.
    services.logind.settings.Login.HandleLidSwitch =
      if config.base.hibernate then "suspend-then-hibernate" else "suspend";
  };
}
