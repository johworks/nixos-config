{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common/base.nix
    ../../modules/nixos/common/maintenance.nix
  ];

  # Lanzaboote signs the NixOS boot chain for UEFI Secure Boot.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    configurationLimit = 5;
    pkiBundle = "/var/lib/sbctl";
    settings.timeout = "menu-force";
  };

  system.activationScripts.windows-boot-entry = ''
    install -D -m0644 ${pkgs.edk2-uefi-shell}/shell.efi /boot/efi/edk2-uefi-shell/shell.efi.unsigned
    ${pkgs.sbsigntool}/bin/sbsign \
      --key /var/lib/sbctl/keys/db/db.key \
      --cert /var/lib/sbctl/keys/db/db.pem \
      --output /boot/efi/edk2-uefi-shell/shell.efi \
      /boot/efi/edk2-uefi-shell/shell.efi.unsigned
    rm -f /boot/efi/edk2-uefi-shell/shell.efi.unsigned

    rm -f /boot/loader/entries/edk2-uefi-shell.conf
    install -D -m0644 ${pkgs.writeText "windows.conf" ''
      title Windows
      efi /efi/edk2-uefi-shell/shell.efi
      options -nointerrupt -nomap -noversion FS0:EFI\Microsoft\Boot\Bootmgfw.efi
      sort-key m_windows
    ''} /boot/loader/entries/windows.conf
  '';

  # Fix for the r8125 NIC issue
  boot.extraModulePackages = [ config.boot.kernelPackages.r8125 ]; # official realtek one
  boot.blacklistedKernelModules = [ "r8169" ]; # r8125 rev 0xc is too new

  networking.hostName = "desktop";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

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
  };

  # Define a user account. Don't forget to set a password with `passwd`.
  users.users.john = {
    isNormalUser = true;
    description = "john";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "john" = import ./home.nix;
    };
  };

  # Install firefox.
  programs.firefox.enable = true;

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    git
    sbctl
    pkgsUnstable.element-desktop
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken.
  system.stateVersion = "25.11";
}
