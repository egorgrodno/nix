{
  description = "My System Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
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
      };
      theme = {
        fontMono = "Inconsolata LGC Nerd Font Mono";
        fontUI = "Overpass Nerd Font";
        background = {
          main = "#16191D";
          light = "#21252B";
        };
        foreground = {
          main = "#DCDFE4";
          light = "#F2F4F5";
          muted = "#ABB2BF";
          dark = "#434956";
        };
        red = "#E06C75";
        green = "#98C379";
        yellow = "#E5C07B";
        blue = "#61AFEF";
        magenta = "#C678DD";
        cyan = "#56B6C2";
        # The ANSI bright half, for terminals. Each is its accent above carried
        # through One Dark Pro's own normal-to-bright step — +0.08 lightness and
        # +0.24 saturation in HSL — so bright text gains vividness, not pallor,
        # and stays on the hue it brightens.
        bright = {
          red = "#F87C86";
          green = "#AAE282";
          yellow = "#FAD48E";
          blue = "#79C3FF";
          magenta = "#DC88F5";
          cyan = "#5CD5E4";
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

        (
          { pkgs, ... }:
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        )

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
        # Run from a NixOS ISO: `nix run github:egorgrodno/nix#repair-boot`.
        repair-boot = pkgs.callPackage ./pkgs/repair-boot { };
        # Installed for every user by modules/nixtools.
        nx-setup = pkgs.callPackage ./pkgs/nx-setup { };
      };
      # The packages are listed so their build-time shellcheck runs here too.
      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
      }
      // self.packages.${system};

      # Portable editor profiles for non-NixOS machines
      homeConfigurations = {
        neovim-qwerty = mkNeovimHome { layout = "qwerty"; };
        neovim-hallmack = mkNeovimHome { layout = "hallmack"; };
      };

      # One configuration per directory in hosts/, named after it.
      nixosConfigurations = lib.mapAttrs (name: _: mkHost name) (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts)
      );
    };
}
