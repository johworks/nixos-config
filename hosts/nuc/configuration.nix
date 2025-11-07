# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      ../../modules/nixos/home-assistant.nix
      #../../modules/nixos/pihole.nix
      ../../modules/nixos/vaultwarden/vaultwarden.nix
      ../../modules/nixos/bedrock-server.nix
      ../../modules/nixos/josh/josh-website.nix
      ../../modules/nixos/ddns/ddns.nix
      #(inputs.shiny-app + "/shiny-app.nix")  # input as flake
      #inputs.shiny-app.nixosModules.webapp
      #inputs.finance-tracking.nixosModules.finance-tracking
    ];

  #  finance-tracking = {
  #    enable = true;
  #    openFirewall = true;
  #    host = "0.0.0.0";
  #    port = 8089;
  #  };

  private.webapp.enable = true;
  private.webapp.port = 8000;
  private.webapp.workDir = "/var/lib/shinyapp";  # only if you want to override the default
  
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

  # Create a media group
  users.groups.media = {};

  # Create dir for mount
  systemd.tmpfiles.rules = [
    "d /data 0775 root media -"
    "d /data/.secret 0775 root media -"

    "d /data/media 0775 root media -"
    "d /data/media/.state 0775 root media -"

    "d /etc/wireguard 0775 root root -"
  ];

  # Mount the USB HDD (root:media)
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/3c4c7e33-f992-4295-9ec2-2f954fe77c27";
    fsType = "ext4";
    options = [ "defaults" ];
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

  # Pull in special ethernet kernal module
  boot.extraModulePackages = [ config.boot.kernelPackages.r8125 ]; # offical realtek one
  boot.blacklistedKernelModules = [ "r8169" ]; # need to use /\ b/c r8125 rev 0xc is too new
  hardware.enableAllFirmware = true;  # Attempt to get ethernet firmware pulled in

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      dns = "none";  # we'll run our own dns
      unmanaged = [ 
        "enp1s0"
        "wlo1"  # just hard disable wifi to prevent auto connect
      ];
      #settings.connection.autoconnect = false;
      #settings.device.wifi.disable = "true";
    };
    useDHCP = false;
    hostName = "john-nuc"; # Define your hostname.

    interfaces.enp1s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.10.2";  # this IP
        prefixLength = 24;
      }];
    };

    defaultGateway = { 
      address = "192.168.10.1";  # router / wireless ap
      interface = "enp1s0";
    };



  };

  boot.kernel.sysctl = { "net.ipv4.ip_forward" = "1"; };


  # DoH + DoT
  services.stubby = {
    enable = true;
    settings = pkgs.stubby.passthru.settingsExample // {
      appdata_dir = "/var/cache/stubby";
      upstream_recursive_servers = [
        # Cloudflare
        {
          address_data = "1.1.1.1";
          tls_auth_name = "cloudflare-dns.com";
        }
        # Quad9
        {
          address_data = "9.9.9.9";
          tls_auth_name = "dns.quad9.net";
        }
      ];
      listen_addresses = [
        "127.0.0.1@8053"
        "0::1@8053"
      ];

    };
  };

  # DNS + DHCP
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "enp1s0";
      bind-interfaces = true;

      # DNS config
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      server = ["127.0.0.1#8053"];  # -> stubby

      # DHCP pool for LAN
      dhcp-range = "192.168.10.50,192.168.10.200,24h";

      # Tell clients to send traffic to the router, and DNS here
      dhcp-option = [
        "option:router,192.168.10.1"      # router / wireless ap
        "option:dns-server,192.168.10.2"  # this pc
      ];

      # Make local names work
      domain = "lan";
      expand-hosts = true;

    };
  };


  networking.firewall.allowedTCPPorts = [ 53 ];     # DNS
  networking.firewall.allowedUDPPorts = [ 53 67 ];  # DNS + DHCP


  # Failed wireguard routing

  #wg-quick.interfaces = { 
  #  wg0 = {
  #    configFile = "/etc/wireguard/wg0.conf";
  #    autostart = true;
  #  };
  #};

  # NAT not needed for LAN traffic
  #nat = {
  #  enable = false;
  #  # Route traffic over the VPN
  #  internalInterfaces = [ "enp1s0" ];
  #  #internalInterfaces = [ ];
  #  externalInterface = "wg0";
  #};

  #firewall.enable = true;
  #firewall.allowedUDPPorts = [ 43996 ];

  #systemd.services.setup-vpn-routing = {
  #  description = "Set up routing rules to send server traffic through wg0";
  #  after = [ "network.target" "wg-quick-wg0.service" ];
  #  wantedBy = [ "multi-user.target" ];
  #  serviceConfig = {
  #    Type = "oneshot";
  #    ExecStart = "${pkgs.writeShellScriptBin "vpn-routing" ''
  #      #!${pkgs.runtimeShell}
  #      ${pkgs.iproute2}/bin/ip rule add from 192.168.10.2 lookup 100
  #      ${pkgs.iproute2}/bin/ip route add default dev wg0 table 100
  #    ''}/bin/vpn-routing";
  #  };
  #};

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.john = {
    isNormalUser = true;
    description = "john";
    extraGroups = [ "networkmanager" "wheel" "media" ];
    #packages = with pkgs; [
    #];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "john";

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


  home-manager = {
    # Make HM use the same pkgs as the system
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit inputs; 
      # Another pkgs that's even newer
      pkgsLatest = import inputs.nixpkgs-latest {
        system = pkgs.stdenv.hostPlatform.system;
      };
    };
    users = {
	  "john" = import ./home.nix;
    };

    backupFileExtension = "backup";
  };


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.PermitRootLogin = "no";
  };

  environment.etc."ssh/ssh_config".text = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile /home/john/.ssh/github_id_ed25519
      IdentitiesOnly yes
  '';
  

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
