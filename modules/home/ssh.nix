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
    };

    # Control known_hosts through home.file
    extraConfig = ''
      HashKnownHosts no
      UpdateHostKeys no
    '';
	
  };
}
