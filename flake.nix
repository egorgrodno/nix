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
            inherit inputs users;
            theme = import ./lib/theme.nix;
            forAllUsers = import ./lib/for-all-users.nix lib users;
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
        # Installed for every user by modules/keyboard-layout.
        kb-layout = pkgs.callPackage ./pkgs/kb-layout { };
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
      homeConfigurations.neovim =
        let
          user = builtins.getEnv "USER";
          home = builtins.getEnv "HOME";
          # Must throw rather than fall back: under pure evaluation getEnv yields
          # "", and a default would install the profile under the wrong account's
          # paths, which home-manager only catches at activation time.
          username =
            if user != "" then
              user
            else
              throw "homeConfigurations.neovim: \$USER is empty, which means evaluation is pure. Pass `--impure`, or set `username` explicitly.";
          homeDirectory = if home != "" then home else "/home/${username}";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs.isDesktop = false;
          modules = [
            ./modules/keyboard-layout/hm.nix
            ./modules/neovim/hm.nix
            ./modules/git/hm.nix
            ./modules/direnv/hm.nix
            {
              home = {
                inherit username homeDirectory;
                stateVersion = "24.05";
              };
              programs.home-manager.enable = true;
            }
          ];
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
