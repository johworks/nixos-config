{
  description = "Nixos and Home Manager flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:

    let
      system = "x86_64-linux";
	  pkgs = nixpkgs.legacyPackages.${system};
    in {

	# For NixOS rebuild
	nixosConfigurations = {

		default = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            hostId = "default";
          };
          modules = [ ./hosts/default/configuration.nix ];
		};


		laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            hostId = "laptop";
          };
          modules = [ ./hosts/laptop/configuration.nix ];
		};
	};


	homeConfigurations = {
		john = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./hosts/laptop/home.nix ];
		};
	};
    };
}

