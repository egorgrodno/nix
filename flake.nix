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

          specialArgs.username = "egor";

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
