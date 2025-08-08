{ ... }: 
{
# Enable git 
  programs.git = {
	enable = true;
	userName = "John";
	userEmail = "jworks2507@gmail.com";
	extraConfig = {
		init.defaultBranch = "main";
		core.editor = "nvim";
        pull.rebase = true;
	};
  };
}
