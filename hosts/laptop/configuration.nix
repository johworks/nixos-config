# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  pkgsUnstable,
  inputs,
  ...
}:
let
  sddm-background = import ../../wallpapers/sunset-field.nix { inherit pkgs; };
  catppuccin-sddm-theme = pkgs.catppuccin-sddm.override {
    flavor = "mocha";
    font = "Noto Sans";
    fontSize = "9";
    background = "${sddm-background}";
    loginBackground = true;
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/nixos/common/base.nix
    ../../modules/nixos/common/maintenance.nix
    ../../modules/nixos/common/hyprland.nix
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Optional: adds `docker` CLI alias
    defaultNetwork.settings.dns_enabled = false;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "john-laptop"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Login graphically
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "catppuccin-mocha-mauve";
      package = pkgs.kdePackages.sddm;
      extraPackages = [ catppuccin-sddm-theme ];
    };
    defaultSession = "hyprland";
  };

  services.pipewire.jack.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.john = {
    isNormalUser = true;
    description = "john";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    pkgsUnstable.element-desktop

    home-manager
    catppuccin-sddm-theme
  ];

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
    settings.PasswordAuthentication = true; # key only access (set to true rn though)
    settings.PermitRootLogin = "no";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
