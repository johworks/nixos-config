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
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/nixos/common/base.nix
    ../../modules/nixos/common/maintenance.nix
    ../../modules/nixos/common/hyprland.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-vm";

  # Enable networking
  networking.networkmanager.enable = true;

  # Improve VM integration
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

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

    # VM guest experience
    spice-vdagent # resolution + clipboard
    xorg.xrandr # let x11 dynamically adjust res

    (catppuccin-sddm.override {
      flavor = "mocha";
      font = "Noto Sans";
      fontSize = "9";
      background = "${sddm-background}";
      loginBackground = true;
    })
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "john" = import ./home.nix;
    };
    # Let home-manger save existing configs as backup
    backupFileExtension = "backup";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
