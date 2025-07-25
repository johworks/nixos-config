# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.home-manager.nixosModules.home-manager
      ../../modules/nixos/home-assistant.nix
      ../../modules/nixos/pihole.nix
      ../../modules/nixos/vaultwarden.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "pcie_aspm=off" ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.opengl = {
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

    # Secrets
    #"d /etc/nixos/secret 0775 root root -"
  ];

  # Mount the USB HDD (root:media)
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/3c4c7e33-f992-4295-9ec2-2f954fe77c27";
    fsType = "ext4";
    options = [ "defaults" ];
  };


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
      dns = "none";
    };
    useDHCP = false;
    hostName = "john-nuc"; # Define your hostname.

    interfaces.enp1s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.10.2";
        prefixLength = 24;
      }];
    };

    defaultGateway = { address = "192.168.10.1"; interface = "enp1s0"; };

    #wg-quick.interfaces = { 
    #  wg0 = {
    #    configFile = "/etc/wireguard/wg0.conf";
    #    autostart = true;
    #  };
    #};

    # NAT not needed for LAN traffic
    nat = {
      enable = false;
      # Route traffic over the VPN
      internalInterfaces = [ "enp1s0" ];
      #internalInterfaces = [ ];
      externalInterface = "wg0";
    };

    firewall.enable = true;
    firewall.allowedUDPPorts = [ 43996 ];

  };

  boot.kernel.sysctl = { "net.ipv4.ip_forward" = "1"; };

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


  home-manager = {
    extraSpecialArgs = { inherit inputs; };
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
