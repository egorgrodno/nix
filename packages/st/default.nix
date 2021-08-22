{ pkgs, ... }:

{ environment.variables =
    { TERMINAL = "st";
    };

  fonts.fonts =
    [ (pkgs.nerdfonts.override { fonts = [ "LiberationMono" ]; })
    ];

  environment.systemPackages =
    [ (pkgs.st.overrideAttrs (oldAttrs: rec {
        patches =
          [
            ./st-nordtheme-0.8.2.diff
            ./st-scrollback-0.8.4.diff
            ./st-scrollback-mouse-20191024-a2c479c.diff
            ./st-vertcenter-20180320-6ac8c8a.diff
            ./st-anysize-0.8.1.diff
            ./st-manual.diff
          ];
      }))
    ];
}
