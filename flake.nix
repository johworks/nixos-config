{
  description = "Nixos and Home Manager flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };    

    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      #inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, 
    nixpkgs,
    home-manager,
    nixarr,
    ... 
  }@inputs:
  {
    # For NixOS rebuild
    nixosConfigurations = {

      # Intel Laptop
      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ 
          ./hosts/laptop/configuration.nix 
          inputs.home-manager.nixosModules.home-manager
        ];
      };

      # Intel Nuc 14
      nuc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ 
          ./hosts/nuc/configuration.nix 
          home-manager.nixosModules.home-manager
          nixarr.nixosModules.default
        ];
      };


    };
  };


}

