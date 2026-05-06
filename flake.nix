{
  description = "Nixos and Home Manager flake";

  inputs = {

    nixpkgsUnstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgsStable = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    home-managerStable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgsStable";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    # Your Neovim repo as a non-flake input (works fine even if it has no flake)
    shared-nvim = {
      url = "github:johworks/shared-nvim";
      flake = false;
    };

    # shiny-app = {
    #   url = "git+ssh://git@github.com/Cgilrein/super_secret_project.git?ref=main";
    #   #flake = false;
    # };

    #    finance-tracking = {
    #      url = "github:johworks/finance_tracking?ref=main";
    #      inputs.nixpkgs.follows = "nixpkgs";
    #    };

  };

  outputs =
    {
      self,
      nixpkgsUnstable,
      nixpkgsStable,
      home-manager,
      home-managerStable,
      sops-nix,
      shared-nvim,
      # shiny-app,
      #    finance-tracking,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      mkPkgs =
        nixpkgsInput:
        import nixpkgsInput {
          inherit system;
          config.allowUnfree = true;
        };

      pkgsUnstable = mkPkgs nixpkgsUnstable;
      pkgsStable = mkPkgs nixpkgsStable;

      mkHost =
        {
          hostName,
          nixpkgsInput,
          extraModules ? [ ],
        }:
        nixpkgsInput.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs pkgsStable pkgsUnstable;
          };
          modules = [ (./hosts + "/${hostName}/configuration.nix") ] ++ extraModules;
        };
    in
    {
      # For NixOS rebuild
      nixosConfigurations = {

        # Intel Laptop
        laptop = mkHost {
          hostName = "laptop";
          nixpkgsInput = nixpkgsUnstable;
          extraModules = [ inputs.home-manager.nixosModules.home-manager ];
        };

        # Intel Nuc 14
        nuc = mkHost {
          hostName = "nuc";
          nixpkgsInput = nixpkgsStable;
          extraModules = [
            home-managerStable.nixosModules.home-manager
            sops-nix.nixosModules.sops
            # shiny-app.nixosModules.webapp
            #          finance-tracking.nixosModules.finance-tracking
          ];
        };

        # VM for desktop testing
        vm = mkHost {
          hostName = "vm";
          nixpkgsInput = nixpkgsUnstable;
          extraModules = [ home-manager.nixosModules.home-manager ];
        };

        # Desktop host with KDE Plasma
        desktop = mkHost {
          hostName = "desktop";
          nixpkgsInput = nixpkgsUnstable;
          extraModules = [ home-manager.nixosModules.home-manager ];
        };

      };
    };

}
