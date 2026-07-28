{
  description = "My System Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      theme = {
        fontMono = "Inconsolata LGC Nerd Font Mono";
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
      # Packages that provide the font families.
      fontPackages = [
        pkgs.nerd-fonts.inconsolata-lgc
        pkgs.nerd-fonts.overpass
      ];
      # Standalone home-manager profile that installs the neovim editor + git for
      # a given keyboard layout. The neovim module carries its own runtime deps
      # so this profile is self-contained.
      #
      # username/homeDirectory default to the invoking user's $USER/$HOME so the
      # profile works on any account; this requires evaluating with `--impure`.
      # Under pure evaluation (getEnv returns "") they fall back to egor.
      mkNeovimHome =
        { layout
        , username ? (let u = builtins.getEnv "USER"; in if u != "" then u else "egor")
        , homeDirectory ? (let h = builtins.getEnv "HOME"; in if h != "" then h else "/home/${username}")
        }:
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
            inherit inputs theme fontPackages users;
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

          # Kept identical to fractal's, so a module argument added later cannot
          # break one host while the other still evaluates.
          specialArgs = {
            inherit inputs theme fontPackages users;
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
