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
      # Standalone home-manager profile that installs the neovim editor + git for
      # a given keyboard layout. The neovim module carries its own runtime deps
      # so this profile is self-contained.
      mkNeovimHome = { layout, username ? "egor", homeDirectory ? "/home/egor" }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { keyboardLayout = layout; isDesktop = false; };
          modules = [
            ./modules/neovim/hm.nix
            ./modules/git/hm.nix
            {
              home = { inherit username homeDirectory; stateVersion = "24.05"; };
              programs.home-manager.enable = true;
            }
          ];
        };

      # Apply a home-manager module (or per-user module function) to every user.
      # `f` may be a plain attrset, or a function `u: attrset` when it needs
      # per-user values like u.homedir.
      mkForAllUsers = users: f:
        builtins.listToAttrs (map (u: {
          name = u.name;
          value = if builtins.isFunction f then f u else f;
        }) users);

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
      # Portable editor profiles for non-NixOS machines
      homeConfigurations = {
        neovim-qwerty   = mkNeovimHome { layout = "qwerty"; };
        neovim-hallmack = mkNeovimHome { layout = "hallmack"; };
      };

      nixosConfigurations = {
        fractal = let
          users = [
            (import ./users/egor.nix)
            (import ./users/forge.nix)
          ];
        in lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit inputs theme pkgs-unstable users;
            forAllUsers = mkForAllUsers users;
          };

          modules =
            nixosConfigurationModules
            ++ homeConfigurationModules
            ++ [
              ./hosts/fractal/configuration.nix
            ];
        };

        thinkpad = let
          users = [ (import ./users/egor.nix) ];
        in lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit theme users;
            forAllUsers = mkForAllUsers users;
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
