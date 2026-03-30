{ ... }:
{
  # Setup SSH to work with GitHub
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        user = "git";
        hostname = "github.com";
        identityFile = "~/.ssh/github_id_ed25519";
      };
      "nuc" = {
        hostname = "192.168.10.1"; # fixed as it's a router rn
        identityFile = "~/.ssh/id_ed25519_nuc";
      };
    };

    # Control known_hosts through home.file
    extraConfig = ''
      HashKnownHosts no
      UpdateHostKeys no
    '';

  };
}
