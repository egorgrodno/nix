{ config, pkgs, username, ... }:

with pkgs;

let
  desktopPackages = [
    (writeShellScriptBin "chromium-without-cors" ''
      chromium --disable-web-security --user-data-dir=.config/chromium-without-cors
    '')
  ];
  systemPackages = [
    wget
    htop
    zip
    unzip
    file
  ];

in {
  environment.systemPackages = if config.base.isNixosSystem
    then systemPackages
    else [];

  home-manager.users.${username} = {
    home.packages =
      [
        fd
        jq
        nodejs
        gcc
        openssh
        xclip

        (writeShellScriptBin "showsource" "cat $(which $1)")

        (writeShellScriptBin "docker-clean" ''
          docker-clean-containers; docker-clean-images
        '')

        (writeShellScriptBin "docker-clean-containers" ''
          docker rm -vf $(docker ps -aq)
        '')

        (writeShellScriptBin "docker-clean-images" ''
          docker rmi -f $(docker images -aq)
        '')
      ]
      ++ (if config.base.isDesktop then desktopPackages else [])
      ++ (if !config.base.isNixosSystem then systemPackages else []);
  };
}
