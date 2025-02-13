{ pkgs, username, ... }:

{
  home-manager.users.${username} = {
    home.packages = [
      pkgs.nodejs

      (pkgs.writeShellScriptBin "chromium-without-cors" ''
        chromium --disable-web-security --user-data-dir=.config/chromium-without-cors
      '')

      (pkgs.writeShellScriptBin "docker-clean" ''
        docker-clean-containers; docker-clean-images
      '')

      (pkgs.writeShellScriptBin "docker-clean-containers" ''
        docker rm -vf $(docker ps -aq)
      '')

      (pkgs.writeShellScriptBin "docker-clean-images" ''
        docker rmi -f $(docker images -aq)
      '')
    ];

  };
}
