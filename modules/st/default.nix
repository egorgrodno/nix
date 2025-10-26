{ config, lib, pkgs, username, ... }:

with lib;

let
  cfg = config.st;

in {
  options = {
    st = {
      enable = mkEnableOption "st terminal emulator";

      fontFamily = mkOption {
        type = types.str;
        default = "Liberation Mono";
      };

      fontSize = mkOption {
        type = types.int;
        default = 18;
      };
    };
  };

  config = mkIf cfg.enable {
    environment.variables.TERMINAL = "st";

    environment.systemPackages =
      let
        src = fetchTarball {
          url = "https://dl.suckless.org/st/st-0.8.4.tar.gz";
          sha256 = "01z6i60fmdi5h6g80rgvqr6d00jxszphrldx07w4v6nq8cq2r4nr";
        };
        patches =
          [ ./st-scrollback-0.8.4.diff
            ./st-scrollback-mouse-20191024-a2c479c.diff
            ./st-vertcenter-20180320-6ac8c8a.diff
            ./st-anysize-0.8.4.diff
            ./st-csi_22_23-0.8.4.diff
            ./st-osc10-20210106-4ef0cbd.diff
            ./st-dynamic-cursor-color-0.8.4.diff
            ./st-bold-is-not-bright-20190127-3be4cf1.diff
            ./st-hidecursor-0.8.3.diff
            ./st-workingdir-20200317-51e19ea.diff
            ./st-xclearwin-20200419-6ee7143.diff
            (pkgs.writeText "my-st-config-patch"
              (import ./my-patch.nix {
                # fontFamily="Inconsolata Nerd Font Mono";
                # fontSize=32;
                fontFamily = cfg.fontFamily;
                fontSize = cfg.fontSize;
              })
            )
          ];

      in [
        (pkgs.st.overrideAttrs (oldAttrs: rec { inherit src patches; }))
      ];

    home-manager.users.${username} = {
      home.packages = [
        (pkgs.writeShellScriptBin "cps" "2>/dev/null 1>/dev/null st -d $PWD & disown")
      ];
    };
  };
}
