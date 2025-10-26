{
  description = "My System Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      specialArgs = {
        username = "egor";
        homedir = "/home/egor";
        theme = {
          fontFamily = "Inconsolata Nerd Font Mono";
          background = {
            main = "#282C34";
            light = "#30343C";
          };
          foreground = {
            main = "#DCDFE4";
            dark = "#434956";
          };
          red = "#E06C75";
          green = "#98C379";
          yellow = "#E5C07B";
          blue = "#61AFEF";
          magenta = "#C678DD";
          cyan = "#56B6C2";
        };
      };
      nixosConfigurationModules = [
        ({ pkgs, ... }: {
          nix.package = pkgs.nixVersions.stable;
          nix.registry.nixpkgs.flake = nixpkgs;
          nix.extraOptions = "experimental-features = nix-command flakes";
        })
      ];
      homeConfigurationModules = [
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        })

        ./home.nix
      ];

    in {
      homeConfigurations = {
        devtools = home-manager.lib.homeManagerConfiguration {
          modules =
            homeConfigurationModules
            ++ [
              ./roles/role-headless-config.nix
              ./roles/role-devtools.nix
            ];
        };
      };

      nixosConfigurations = {
        fractal = lib.nixosSystem {
          inherit system pkgs specialArgs;

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/fractal/configuration.nix
              ./roles/role-desktop-config.nix
            ];
        };

        thinkpad = lib.nixosSystem {
          inherit system pkgs specialArgs;

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/thinkpad/configuration.nix
              ./roles/role-desktop-config.nix
            ];
        };
      };
    };
}
