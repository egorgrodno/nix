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
    in
    {
      nixosConfigurations = {
        thinkpad = lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            username = "egor";
            homedir = "/home/egor";
            theme = {
              fontFamily = "Inconsolata Nerd Font";
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

          modules = [
            home-manager.nixosModules.home-manager

            ({ pkgs, ... }: {
              nix.package = pkgs.nixFlakes;
              nix.registry.nixpkgs.flake = nixpkgs;
              nix.extraOptions = "experimental-features = nix-command flakes";

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            })

            ./hosts/thinkpad/configuration.nix
          ];
        };
      };
    };
}
