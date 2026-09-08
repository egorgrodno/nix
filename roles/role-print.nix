{ pkgs, ... }:

{
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.brlaser ];
  # cups-browsed mirrors every mDNS printer into a second implicitclass:// queue
  # whose destination resolves only while browsed tracks it, so jobs sent there
  # vanish. Real queues keep .local URIs, which Avahi resolves at print time.
  services.printing.browsed.enable = false;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
