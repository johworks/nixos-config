{
  description = "Nixos and Home Manager flake";

  inputs = {

    nixpkgsUnstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgsStable = {
      url = "github:nixos/nixpkgs/nixos-26.05";
    };

    # Update Vaultwarden independently of the hosts' system packages.
    nixpkgsVaultwarden = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    # Keep OpenCode current without upgrading the desktop's other packages.
    nixpkgsOpencode = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    home-managerStable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgsStable";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
      inputs.home-manager.follows = "home-manager";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # Refresh overlay APIs while Lanzaboote keeps its pinned Rust toolchain.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    # Your Neovim repo as a non-flake input (works fine even if it has no flake)
    shared-nvim = {
      url = "github:johworks/shared-nvim";
      flake = false;
    };

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
      formatter.${system} = pkgsUnstable.nixfmt;

      packages.${system} = {
        nixos-lab = pkgsUnstable.writeShellApplication {
          name = "nixos-lab";
          runtimeInputs = with pkgsUnstable; [
            nix
            openssh
            git
          ];
          text = ''
            exec ${pkgsUnstable.python3}/bin/python3 ${./scripts}/nixos-lab/lab.py "$@"
          '';
        };

        update-prepare = pkgsUnstable.writeShellApplication {
          name = "update-prepare";
          runtimeInputs = [
            pkgsUnstable.git
            pkgsUnstable.nix
            pkgsUnstable.nixfmt
            pkgsUnstable.openssh
            pkgsUnstable.nodejs
          ];
          text = ''
            exec ${pkgsUnstable.python3}/bin/python3 ${./scripts/updates/prepare.py} "$@"
          '';
        };

        hyprland-lab = pkgsUnstable.writeShellApplication {
          name = "hyprlab";
          runtimeInputs = with pkgsUnstable; [
            nix
            openssh
            git
          ];
          text = ''
            exec ${pkgsUnstable.python3}/bin/python3 ${./scripts/hyprland-lab/lab.py} "$@"
          '';
        };
      };

      checks.${system} = {
        nixos-lab = pkgsUnstable.runCommand "nixos-lab-tests" { } ''
          cp -r ${./scripts} scripts
          chmod -R u+w scripts
          ${pkgsUnstable.python3}/bin/python3 -m unittest discover -s scripts/nixos-lab -v
          touch "$out"
        '';

        update-preparation =
          pkgsStable.runCommand "update-preparation-tests"
            {
              nativeBuildInputs = [ pkgsStable.git ];
              TEST_SYSTEM = pkgsStable.runCommand "nixos-system-update-test" { } ''mkdir "$out"'';
            }
            ''
              cp ${./scripts/updates/prepare.py} prepare.py
              cp ${./scripts/updates/test_prepare.py} test_prepare.py
              ${pkgsStable.python3}/bin/python3 test_prepare.py
              touch "$out"
            '';

        hyprland-lab = pkgsUnstable.runCommand "hyprland-lab-tests" { } ''
          cp ${./scripts/hyprland-lab/lab.py} lab.py
          cp ${./scripts/hyprland-lab/test_lab.py} test_lab.py
          ${pkgsUnstable.python3}/bin/python3 -m unittest -v
          touch "$out"
        '';

        signal-updates = pkgsStable.runCommand "signal-updates-tests" { } ''
          export SIGNAL_CLI=${pkgsUnstable.signal-cli}/bin/signal-cli
          cp ${./modules/nixos/signal-updates/client.py} client.py
          cp ${./modules/nixos/signal-updates/test_client.py} test_client.py
          ${pkgsStable.python3}/bin/python3 test_client.py
          export JAVAX_NET_SSL_TRUSTSTORE=${self.nixosConfigurations.nuc.config.system.build.signalUpdatesTrustStore}/cacerts
          # Test signal-cli's actual JVM, which can differ from the default JRE.
          signalJavaHome=$(${pkgsStable.gnused}/bin/sed -n "s/^export JAVA_HOME='\([^']*\)'$/\1/p" "$SIGNAL_CLI")
          test -x "$signalJavaHome/bin/java"
          "$signalJavaHome/bin/java" ${./modules/nixos/signal-updates/TestTrust.java} "$JAVAX_NET_SSL_TRUSTSTORE"
          touch "$out"
        '';

        ax1450-reconcile =
          pkgsStable.runCommand "ax1450-reconcile-tests"
            {
              nativeBuildInputs = [
                pkgsStable.python3
                pkgsStable.bash
              ];
            }
            ''
              export AX1450_TEST_SHELL=${pkgsStable.busybox}/bin/ash
              export AX1450_TEST_WRAPPER=${self.nixosConfigurations.nuc.config.system.build.ax1450-reconcile}/bin/ax1450-reconcile
              cp ${./modules/nixos/ax1450/reconcile-remote.sh} reconcile-remote.sh
              python3 ${./modules/nixos/ax1450/test_reconcile.py}
              touch "$out"
            '';

        ax1450-metrics =
          pkgsStable.runCommand "ax1450-metrics-tests" { nativeBuildInputs = [ pkgsStable.python3 ]; }
            ''
              cp ${./modules/nixos/ax1450/metrics.py} metrics.py
              cp ${./modules/nixos/ax1450/test_metrics.py} test_metrics.py
              python3 test_metrics.py
              touch "$out"
            '';
      };

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
          ];
        };

        # VM for desktop testing
        vm = mkHost {
          hostName = "vm";
          nixpkgsInput = nixpkgsUnstable;
          extraModules = [ home-manager.nixosModules.home-manager ];
        };

        hyprland-lab = mkHost {
          hostName = "vm";
          nixpkgsInput = nixpkgsUnstable;
          extraModules = [
            home-manager.nixosModules.home-manager
            ./hosts/vm/lab.nix
          ];
        };

        # Desktop host with KDE Plasma
        desktop = mkHost {
          hostName = "desktop";
          nixpkgsInput = nixpkgsUnstable;
          extraModules = [
            home-manager.nixosModules.home-manager
            inputs.lanzaboote.nixosModules.lanzaboote
          ];
        };

      };

    };

}
