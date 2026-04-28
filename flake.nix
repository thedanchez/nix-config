{
  description = "Danchez NixOS server configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, home-manager, agenix, ... }: {
    nixosConfigurations.fsn-dev-1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        {
          nixpkgs.overlays = [
            (final: prev: {
              unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
            })
          ];
        }
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dan = import ./home/dan.nix;
          home-manager.users.cortex = import ./home/cortex.nix;
        }
        ./hosts/hetzner/fsn-dev-1
      ];
    };
  };
}
