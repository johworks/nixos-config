{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        HashKnownHosts = false;
        UpdateHostKeys = false;
      };
      "github.com" = {
        User = "git";
        HostName = "github.com";
        IdentityFile = "~/.ssh/github_id_ed25519";
      };
      "nuc" = {
        HostName = "192.168.10.1";
        IdentityFile = "~/.ssh/id_ed25519_nuc";
      };
    };
  };
}
