{ pkgs, isDesktop, ... }:

with pkgs;

let
  desktopPackages = [
    (writeShellScriptBin "chromium-without-cors" ''
      chromium --disable-web-security --user-data-dir=.config/chromium-without-cors
    '')
  ];
in {
  home.packages = [
    fd
    jq
    nodejs
    gcc
    openssh
    xclip

    (writeShellScriptBin "showsrc" "cat $(which $1)")

    (writeShellScriptBin "docker-clean" ''
      docker-clean-containers; docker-clean-images
    '')

    (writeShellScriptBin "docker-clean-containers" ''
      docker rm -vf $(docker ps -aq)
    '')

    (writeShellScriptBin "docker-clean-images" ''
      docker rmi -f $(docker images -aq)
    '')
  ] ++ (if isDesktop then desktopPackages else []);
}
