{ wallpaper }:

{ pkgs, ... }:

{ environment.systemPackages = [ pkgs.feh ];
  environment.variables =
    { WALLPAPER = toString wallpaper;
    };
}
