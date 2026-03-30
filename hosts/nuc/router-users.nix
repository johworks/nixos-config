{ pkgs, inputs, ... }:

{
  # Create a media group
  users.groups.media = { };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.john = {
    isNormalUser = true;
    description = "john";
    extraGroups = [
      "networkmanager"
      "wheel"
      "media"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6u080JUBY1CNv0JAsKbTe2pQ4d1cuyFykJrlJ5HIyh desktop->nuc"
    ];
    #packages = with pkgs; [
    #];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "john";

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

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  environment.etc."ssh/ssh_config".text = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile /home/john/.ssh/github_id_ed25519
      IdentitiesOnly yes
  '';
}
