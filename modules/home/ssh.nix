{ lib, options, ... }:
let
  sharedDefaults = {
    hashKnownHosts = false;
    extraOptions.UpdateHostKeys = "no";
  };
in
{
  # Setup SSH to work with GitHub
  programs.ssh =
    {
      enable = true;
      matchBlocks = {
        "*" = sharedDefaults;
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
    }
    // lib.optionalAttrs (options.programs.ssh ? enableDefaultConfig) {
      enableDefaultConfig = false;
    }
    // lib.optionalAttrs (!(options.programs.ssh ? enableDefaultConfig)) {
      extraConfig = ''
        HashKnownHosts no
        UpdateHostKeys no
      '';
    };
}
