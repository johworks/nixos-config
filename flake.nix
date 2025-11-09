{
  description = "Nixos and Home Manager flake";

  inputs = {

    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgs-latest = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgs-stable-25p05 = {
      url = "github:nixos/nixpkgs/nixos-25.05";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };    

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Your Neovim repo as a non-flake input (works fine even if it has no flake)
    shared-nvim = {
      url = "github:johworks/shared-nvim";
      flake = false;
    };

    shiny-app = {
      #url = "git+ssh://git@github.com/Cgilrein/super_secret_project.git?ref=flake-dev";
      url = "git+ssh://git@github.com/Cgilrein/super_secret_project.git?ref=dev";
      #flake = false;
    };

    #    finance-tracking = {
    #      url = "github:johworks/finance_tracking?ref=main";
    #      inputs.nixpkgs.follows = "nixpkgs";
    #    };

  };

  outputs = { 
    self,
    nixpkgs,
    nixpkgs-latest,
    nixpkgs-stable-25p05,
    home-manager,
    sops-nix,
    shared-nvim,
    shiny-app,
    #    finance-tracking,
    ... 
  }@inputs:
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs { inherit system; };

    stablePkgs = import nixpkgs-stable-25p05 { inherit system; };
  in 
  {
    # For NixOS rebuild
    nixosConfigurations = {

      # Intel Laptop
      laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs stablePkgs;
        };
        modules = [
          ./hosts/laptop/configuration.nix 
          inputs.home-manager.nixosModules.home-manager
        ];
      };

      # Intel Nuc 14
      nuc = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs stablePkgs;
        };
        modules = [
          ./hosts/nuc/configuration.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          shiny-app.nixosModules.webapp
            #          finance-tracking.nixosModules.finance-tracking
        ];
      };


    };
  };


}

