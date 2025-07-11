# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:
let
  bedrock-fhs = import ../../modules/nixos/bedrock/bedrock-fhs.nix { inherit pkgs; };
  bedrock-server = import ../../modules/nixos/bedrock/bedrock-server.nix { inherit pkgs; };
in 
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.home-manager.nixosModules.home-manager
      #../../modules/nixos/bedrock/bedrock-connect.nix
    ];


  virtualisation.podman = {
    enable = true;
    dockerCompat = true;  # Optional: adds `docker` CLI alias
    defaultNetwork.settings.dns_enabled = false;

    #networks.bedrockconnectnet.subnet = "10.89.0.0/24";
  };


  ### Minecraft Bedrock Server

  systemd.tmpfiles.rules = [
    "d /var/lib/bedrock 0755 bedrock bedrock -"
  ];

  users.users.bedrock = {
    isSystemUser = true;
    home = "/var/lib/bedrock";
    group = "bedrock";
  };

  users.groups.bedrock = { };

  systemd.services.bedrock-fhs = {
    description = "Minecraft Bedrock Dedicated Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${bedrock-fhs}/bin/bedrock-fhs";
      WorkingDirectory = "/var/lib/bedrock";
      User = "bedrock";
      Group = "bedrock";
      Restart = "always";
      RestartSec = "5";
      NoNewPrivileges = true;
    };

    # Make sure the world directory exists
    preStart = ''
      mkdir -p /var/lib/bedrock

      cp -n ${bedrock-server}/*.json /var/lib/bedrock/ || true
      cp -n ${bedrock-server}/*.txt /var/lib/bedrock/ || true
      cp -n ${bedrock-server}/*.bin /var/lib/bedrock/ || true
      cp -n ${bedrock-server}/server.properties /var/lib/bedrock/ || true
      cp -n ${bedrock-server}/bedrock_server /var/lib/bedrock/
      chmod +x /var/lib/bedrock/bedrock_server

      cp -rn ${bedrock-server}/resource_packs /var/lib/bedrock/ || true
      cp -rn ${bedrock-server}/behavior_packs /var/lib/bedrock/ || true
      cp -rn ${bedrock-server}/definitions /var/lib/bedrock/ || true
    '';
  };


  networking.firewall.allowedTCPPorts = [ 19132 ];
  networking.firewall.allowedUDPPorts = [ 19132 ];

  ### Minecraft Bedrock Server


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "john-laptop"; # Define your hostname.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable networking
  networking.networkmanager.enable = true;

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
  # You can disable this if you're only using the Wayland session.
  #services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  #services.desktopManager.plasma6.enable = true;

  # Enable automatic login for the user.
  #services.displayManager.autoLogin.enable = true;
  #services.displayManager.autoLogin.user = "john";

  # Login graphically
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "catppuccin-mocha";
      package = pkgs.kdePackages.sddm;
    };
    defaultSession = "hyprland";
  };

  # Enable the gnome-keyring daemon for your user
  #systemd.user.services.gnome-keyring-daemon = {
  #  description = "GNOME Keyring Daemon";
  #  serviceConfig.ExecStart = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --foreground --components=secrets";
  #  wantedBy = [ "default.target" ];
  #};

  # Enable hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Desktop portals
  services.dbus.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ 
    pkgs.xdg-desktop-portal-gtk 
    pkgs.xdg-desktop-portal-hyprland
  ];

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
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.john = {
    isNormalUser = true;
    description = "john";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Allow unfree packages (Like Discord)
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget

    home-manager

    bedrock-fhs

    #nerd-fonts.jetbrains-mono

    #sddm-astronaut
    
    (catppuccin-sddm.override {
      flavor = "mocha";
      font  = "Noto Sans";
      fontSize = "9";
      background = "${../../wallpapers/forest-3.jpg}";
      loginBackground = true;
    })

  ];

  # Make sure fonts installed here actually get picked up
  fonts.fontconfig.enable = true;
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "john" = import ./home.nix;
    };
    # Let home-manger save existing configs as backup
    backupFileExtension = "backup";
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;  # key only access (set to true rn though)
    settings.PermitRootLogin = "no";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

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
  system.stateVersion = "24.11"; # Did you read the comment?

}
