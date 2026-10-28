{
  description = "My System Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    bosun.url = "github:egorgrodno/bosun";
    bosun.inputs.nixpkgs.follows = "nixpkgs";
    bosun.inputs.treefmt-nix.follows = "treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            gum = final.callPackage ./pkgs/gum { inherit (prev) gum; };
            xdg-utils = final.callPackage ./pkgs/xdg-utils { inherit (prev) xdg-utils; };
            bosun = inputs.bosun.packages.${system}.default;
          })
        ];
      };
      # One palette per color scheme, under the same names. `background.raised`
      # lifts panels, popups and tooltips off `main`, which the windows share:
      # a shadow barely shows on the dark one. `background.desktop` is
      # Hyprland's background, which the lock screen and greeter must match.
      # Foreground tones run from `strong`, the bar's text, to `faint`; `black`
      # and `white` are the terminal's.
      theme = {
        fontMono = "Inconsolata LGC Nerd Font Mono";
        fontUI = "Overpass Nerd Font";
        dark = {
          background.main = "#16191D";
          background.raised = "#282C34";
          background.desktop = "#16191D";
          foreground = {
            strong = "#FFFFFF";
            main = "#DCDFE4";
            muted = "#ABB2BF";
            faint = "#434956";
          };
          red = "#E06C75";
          green = "#98C379";
          yellow = "#E5C07B";
          blue = "#61AFEF";
          magenta = "#C678DD";
          cyan = "#56B6C2";
          # One Dark's dark yellow and dark red, outside the ANSI eight.
          orange = "#D19A66";
          darkRed = "#BE5046";
          black = "#21252B";
          white = "#ABB2BF";
          # The ANSI bright half, for terminals. Each accent is carried through
          # One Dark Pro's own normal-to-bright step — +0.08 lightness and +0.24
          # saturation in HSL — so bright text gains vividness, not pallor, and
          # stays on the hue it brightens.
          bright = {
            black = "#434956";
            red = "#F87C86";
            green = "#AAE282";
            yellow = "#FAD48E";
            blue = "#79C3FF";
            magenta = "#DC88F5";
            cyan = "#5CD5E4";
            white = "#F2F4F5";
          };
        };
        # One Light. Every ANSI color stays readable on the background, white
        # included, as a program printing white text assumes a dark terminal.
        light = {
          background.main = "#FAFAFA";
          background.raised = "#FFFFFF";
          # One Light's third UI level, as plain white glares.
          background.desktop = "#DBDBDC";
          foreground = {
            strong = "#202227";
            main = "#383A42";
            muted = "#696C77";
            faint = "#A0A1A7";
          };
          red = "#E45649";
          green = "#50A14F";
          yellow = "#C18401";
          blue = "#4078F2";
          magenta = "#A626A4";
          cyan = "#0184BC";
          orange = "#986801";
          darkRed = "#CA1243";
          black = "#383A42";
          white = "#A0A1A7";
          # The bright step turned toward contrast on a light background: -0.08
          # lightness, saturation kept.
          bright = {
            black = "#696C77";
            red = "#DF3525";
            green = "#428642";
            yellow = "#986801";
            blue = "#1A5DEF";
            magenta = "#851E83";
            cyan = "#016893";
            white = "#BCBEC4";
          };
        };
      };
      fontPackages = [
        pkgs.nerd-fonts.inconsolata-lgc
        pkgs.nerd-fonts.overpass
      ];
      # Must throw rather than fall back: under pure evaluation getEnv yields "",
      # and a default would install the profile under the wrong account's paths,
      # which home-manager only catches at activation time.
      requireEnv =
        var: arg:
        let
          value = builtins.getEnv var;
        in
        if value != "" then
          value
        else
          throw "mkNeovimHome: \$${var} is empty, which means evaluation is pure. Pass `--impure`, or set `${arg}` explicitly.";
      mkNeovimHome =
        {
          layout,
          username ? requireEnv "USER" "username",
          homeDirectory ? (
            let
              h = builtins.getEnv "HOME";
            in
            if h != "" then h else "/home/${username}"
          ),
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            keyboardLayout = layout;
            isDesktop = false;
          };
          modules = [
            ./modules/neovim/hm.nix
            ./modules/git/hm.nix
            {
              home = {
                inherit username homeDirectory;
                stateVersion = "24.05";
              };
              programs.home-manager.enable = true;
            }
          ];
        };

      # Apply a home-manager module (or per-user module function) to every user.
      # `f` may be a plain attrset, or a function `u: attrset` when it needs
      # per-user values like u.homedir.
      mkForAllUsers =
        users: f:
        builtins.listToAttrs (
          map (u: {
            name = u.name;
            value = if builtins.isFunction f then f u else f;
          }) users
        );

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      nixosConfigurationModules = [
        (
          { pkgs, ... }:
          {
            nix.package = pkgs.nixVersions.stable;
            nix.registry.nixpkgs.flake = nixpkgs;
            nix.extraOptions = "experimental-features = nix-command flakes";
          }
        )
      ];

      homeConfigurationModules = [
        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }

        ./home.nix
      ];

      # host.nix is data the installer writes, so the hostname and stateVersion
      # come from it and the directory name rather than from configuration.nix.
      mkHost =
        name:
        let
          host = import ./hosts/${name}/host.nix;
          users = map (u: import ./users/${u}.nix) host.users;
        in
        lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit
              inputs
              theme
              fontPackages
              users
              ;
            forAllUsers = mkForAllUsers users;
          };

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/${name}/configuration.nix
              {
                networking.hostName = name;
                system.stateVersion = host.stateVersion;
              }
            ];
        };

    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;

      packages.${system} = {
        # Run from a NixOS ISO: `nix run github:egorgrodno/nix#<name>`.
        install = pkgs.callPackage ./pkgs/install { };
        repair-boot = pkgs.callPackage ./pkgs/repair-boot { };
        # The overlay's: installed for every user by modules/nixtools.
        gum = pkgs.gum;
        # The overlay's: every package here and on the hosts gets it as xdg-utils.
        xdg-utils = pkgs.xdg-utils;
        # Installed for every user by modules/nixtools.
        nx-setup = pkgs.callPackage ./pkgs/nx-setup { };
        nx-iso = pkgs.callPackage ./pkgs/nx-iso { };
        nx-flash = pkgs.callPackage ./pkgs/nx-flash { };
        # Installed for every user by modules/craft.
        craft-update = pkgs.callPackage ./pkgs/craft-update { };
        # Installed for every user by modules/git.
        carve = pkgs.callPackage ./pkgs/carve { };
        git-secret-scan = pkgs.callPackage ./pkgs/git-secret-scan { };
        # Installed for every user by modules/craft, with the apps' caches.
        mcp-lazy = pkgs.callPackage ./pkgs/mcp-lazy { };
        # Run by the bar's format panel, from modules/quickshell.
        usb-format = pkgs.callPackage ./pkgs/usb-format { };
      };
      # The packages are listed so their build-time shellcheck and Go tests run
      # here too.
      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
      }
      // self.packages.${system};

      # Portable editor profiles for non-NixOS machines
      homeConfigurations = {
        neovim-qwerty = mkNeovimHome { layout = "qwerty"; };
        neovim-hallmack = mkNeovimHome { layout = "hallmack"; };
      };

      # One configuration per directory in hosts/, named after it, and the rescue
      # stick's, whose ISO nx-iso builds. The ISO is no package: `checks` builds
      # every package.
      nixosConfigurations =
        lib.mapAttrs (name: _: mkHost name) (
          lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts)
        )
        // {
          rescue = lib.nixosSystem {
            inherit system pkgs;
            specialArgs = { inherit inputs; };
            modules = nixosConfigurationModules ++ [ ./rescue/configuration.nix ];
          };
        };
    };
}
