{ pkgs, ... }:

{ environment.systemPackages =
    with pkgs; [
      git
      unzip
      zip
    ];
}
