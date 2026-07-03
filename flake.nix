{
  description = "Declarative workstation + dev shells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      username = "davidporkka";
      homeDirectory = "/home/davidporkka";
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
        extraSpecialArgs = {
          inherit username homeDirectory;
        };
      };

      devShells.${system} = import ./shells.nix { inherit pkgs; };

      # Convenience apps so `nix run .#home-manager-switch` works without
      # having home-manager on PATH first.
      apps.${system} = {
        home-manager-switch = {
          type = "app";
          program = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
        };
      };
    };
}
