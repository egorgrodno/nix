{ pkgs, ... }:

{ environment.systemPackages =
    with pkgs; [
      git
      zip
      unzip
      xclip
    ];
}
