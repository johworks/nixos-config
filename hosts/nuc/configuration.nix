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
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/nixos/common/base.nix
    ../../modules/nixos/common/maintenance.nix
    ./router-hardware.nix
    ./router-networking.nix
    ./router-users.nix
    ../../modules/nixos/vaultwarden/vaultwarden.nix
    ../../modules/nixos/blog-static.nix
    ../../modules/nixos/ddns/ddns.nix
    ../../modules/nixos/stremio/stremio.nix
    ../../modules/nixos/matrix/matrix.nix
    ../../modules/nixos/matrix-rtc/matrix-rtc.nix
    ../../modules/nixos/qos.nix
  ];

  # Make larger downloads faster
  nix.settings = {
    # Default is 10 MiB — 50–100 MiB works well for most systems
    download-buffer-size = 104857600; # 100 MiB
    # Optional but recommended:
    max-jobs = "auto"; # Use all cores for builds
    cores = 0; # Let Nix decide per job
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "pcie_aspm=off" ];

  # Keep more rollback history on the NUC than on workstation-style systems.
  nix.gc.options = "--delete-older-than 90d";

  # Keep Intel media support available for any remaining hardware transcoding use.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Configure SOPS-NIX
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/john/.config/sops/age/keys.txt"; # no comments allowed in here

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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    pciutils
    ethtool
    dig
    wireguard-tools
    openssl
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
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
