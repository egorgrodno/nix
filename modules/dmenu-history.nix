{ pkgs, username, ... }:

with builtins;

let
  dmenuHistory = fetchurl {
    url = "https://tools.suckless.org/dmenu/scripts/dmenu_run_with_command_history/dmenu_run_history";
    sha256 = "02fz6i391f6c1f39p0r8p37rbfqfsj3m0w0ylzv857w0w4ibhsp4";
  };
in {
  home-manager.users.${username} = {
    home.packages = [
      (pkgs.writeScriptBin "dmenu-history" (readFile dmenuHistory))

      (pkgs.writeScriptBin "dmenu-path" ''
        cachedir="''${XDG_CACHE_HOME:-"$HOME/.cache"}"
        cache="$cachedir/dmenu_run"

        ls -lL $(echo "$PATH" | tr : ' ') 2> /dev/null | awk '$1 ~ /^[^d].*x/ && $NF != "[" { print $NF }' | sort -u > "$cache"
      '')
    ];
  };
}
