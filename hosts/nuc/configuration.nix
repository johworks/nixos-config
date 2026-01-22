# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./router-hardware.nix
      ./router-networking.nix
      ./router-users.nix
      # ./router-storage.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      ../../modules/nixos/home-assistant.nix
      ../../modules/nixos/vaultwarden/vaultwarden.nix
      ../../modules/nixos/bedrock-server.nix
      ../../modules/nixos/josh/josh-website.nix
      ../../modules/nixos/ddns/ddns.nix
      ../../modules/nixos/stremio/stremio.nix
      ../../modules/nixos/invidious/invidious.nix
      ../../modules/nixos/qos.nix
    ];

   sops.secrets."webapp_deploy_key" = {
     owner = "shinyapp";
     mode = "0400";
     path = "/run/secrets/webapp_deploy_key";
   };

   sops.secrets."google_ai" = {
     owner = "shinyapp";
     mode = "0400";
     path = "/run/secrets/google_ai";
   };

   sops.secrets."github_webhook" = {
     owner = "root";
     mode = "0400";
     path = "/run/secrets/github_webhook";
   };

  private.webapp = {
    enable = true;
    workDir = "/var/lib/shinyapp";
    port = 5000;

    reverseProxy = {
      enable = true;
      hostName = "kensfatcock.com";
      #serverAliases = [ "www.kensfatcock.com" ];  # acme will fail until this is added as a CNAME
      enableACME = true;   # ensure security.acme accepts terms + email elsewhere
      forceSSL = true;
    };

    environment = { GOOGLE_API_KEY = "/run/secrets/google_ai"; };

    autoDeploy = {
      enable = true;
      repoUrl = "git+ssh://git@github.com/Cgilrein/super_secret_project.git";
      branch = "main";
      keyFile = /run/secrets/webapp_deploy_key;
      secretFile = /run/secrets/github_webhook;
      listenAddress = "127.0.0.1";
      listenPort = 9000;
    };

  };



  # Make larger downloads faster
  nix.settings = {
    # Default is 10 MiB — 50–100 MiB works well for most systems
    download-buffer-size = 104857600; # 100 MiB
    # Optional but recommended:
    max-jobs = "auto";        # Use all cores for builds
    cores = 0;                # Let Nix decide per job
  };


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "pcie_aspm=off" ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.graphics= {  # opengl
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Configure SOPS-NIX
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/john/.config/sops/age/keys.txt";  # no comments allowed in here

  # First try adding to home-manager as an ENV var
  #sops.secrets.ssh-key = {
  #  sopsFile = ./secrets/github_id_ed25519;
  #  owner = "john";
  #  mode = "0600";
  #  path = "/home/john/.ssh/github_id_ed25519";
  #};
  #
  #programs.ssh = {
  #  enable = true;
  #  matchBlocks = {
  #    "github.com" = {
  #      user = "git";
  #      hostname = "github.com";
  #      identityFile = "~/.ssh/github_id_ed25519";
  #    };
  #  };
  #};

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";


  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the XFCE Desktop Environment.
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;


  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    home-manager
    pciutils
    intel-media-driver
    ethtool
    dig
    wireguard-tools
    openssl
  ];

  environment.variables = { EDITOR = "nvim"; VISUAL = "nvim"; };




  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
