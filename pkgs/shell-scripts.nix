{ pkgs, username, homedir, ... }:

let
  btConnect = mac: "bluetoothctl -- connect ${mac}";
  nodeScript = binjs: "${pkgs.nodejs}/bin/node ${binjs}";
  shellScripts = [
    {
      name = "cps";
      script = "2>/dev/null 1>/dev/null st -d $PWD & disown";
    }
    {
      name = "nxe";
      script = "st -d /etc/nixos -e vim home.nix";
    }
    {
      name = "nxu";
      script = "nix flake update --flake /etc/nixos";
    }
    {
      name = "nxs";
      script = "nixos-rebuild switch --flake /etc/nixos";
    }
    {
      name = "nxb";
      script = "nixos-rebuild build --flake /etc/nixos";
    }
    {
      name = "nxt";
      script = "nixos-rebuild test --flake /etc/nixos";
    }
    {
      name = "bt-on";
      script = ''
        systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service
        bluetoothctl -- power on
      '';
    }
    {
      name = "bt-off";
      script = "bluetoothctl -- power off";
    }
    {
      name = "bt-connect-sony";
      script = btConnect "14:3F:A6:A8:73:D7";
    }
    {
      name = "bt-connect-jbl";
      script = btConnect "F8:5C:7D:94:22:E8";
    }
    {
      name = "chromium-without-cors";
      script = "chromium --disable-web-security --user-data-dir=.config/chromium-without-cors";
    }
    {
      name = "docker-clean";
      script = "docker-clean-containers; docker-clean-images";
    }
    {
      name = "docker-clean-containers";
      script = "docker rm -vf $(docker ps -aq)";
    }
    {
      name = "docker-clean-images";
      script = "docker rmi -f $(docker images -aq)";
    }
    {
      name = "pp";
      script = nodeScript "${homedir}/Projects/code-vault/packages/package-json-manager/build-current/bin.js";
    }
    {
      name = "pt";
      script = nodeScript "${homedir}/Projects/code-vault/packages/sprint-board/build-current/bin.js";
    }
  ];
in
{
  home-manager.users.${username} = {
    home.packages = map ({ name, script }: pkgs.writeShellScriptBin name script) shellScripts;
  };
}
