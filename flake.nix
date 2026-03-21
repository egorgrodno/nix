{
  description = "My System Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/master";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      theme = {
        fontMono = "Inconsolata Nerd Font Mono";
        fontUI   = "Overpass Nerd Font";
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
      mkNeovim = { keyboardLayout ? "qwerty" }:
        let
          runtimeDir = pkgs.runCommand "nvim-runtime" {} ''
            mkdir -p $out/lua $out/snippets
            cp ${pkgs.writeText "config.lua" (import ./modules/neovim/lua-config.nix {
              config = { base.keyboard.layout = keyboardLayout; };
            })} $out/lua/config.lua
            cp ${./modules/neovim/snippets.lua} $out/snippets/all.lua
          '';
        in pkgs.neovim.override {
          configure = {
            packages.bundled = {
              opt = [ pkgs.vimPlugins.packer-nvim ];
            };
            customRC = ''
              set runtimepath^=${runtimeDir}
              packadd packer.nvim
              lua require('config')
            '';
          };
        };

      nixosConfigurationModules = [
        ({ pkgs, ... }: {
          nix.package = pkgs.nixVersions.stable;
          nix.registry.nixpkgs.flake = nixpkgs;
          nix.extraOptions = "experimental-features = nix-command flakes";
        })
      ];
      neovimPkg         = mkNeovim {};
      neovimHallmackPkg = mkNeovim { keyboardLayout = "hallmack"; };

      homeConfigurationModules = [
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        })

        ./home.nix
      ];

    in {
      packages.${system} = {
        neovim          = neovimPkg;
        neovim-hallmack = neovimHallmackPkg;
      };

      apps.${system} = {
        neovim = {
          type = "app";
          program = "${neovimPkg}/bin/nvim";
        };
        neovim-hallmack = {
          type = "app";
          program = "${neovimHallmackPkg}/bin/nvim";
        };
      };

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
        fractal-wayland = lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit inputs theme pkgs-unstable;
            users = [
              (import ./users/hy.nix)
              (import ./users/egor.nix)
              (import ./users/forge.nix)
            ];
          };

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/fractal/configuration.nix
              ./roles/role-wayland-desktop-config.nix
            ];
        };

        fractal = lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit theme;
            users = [ (import ./users/egor.nix) ];
          };

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/fractal/configuration.nix
              ./roles/role-x11-desktop-config.nix
            ];
        };

        thinkpad = lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit theme;
            users = [ (import ./users/egor.nix) ];
          };

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/thinkpad/configuration.nix
            ];
        };
      };
    };
}
