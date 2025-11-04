{ config, pkgs, inputs,... }:

# This exists, but don't use it. I'm not sure it's even right.

{
  
  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/server.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")  # moved to a flake
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
    ../../modules/home/brave.nix
  ];
	
  # Enable git 
  programs.git = {
	enable = true;
	userName = "John";
	userEmail = "jworks2507@gmail.com";
	extraConfig = {
		init.defaultBranch = "main";
		core.editor = "nvim";
	};
  };

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
  };



  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = config.profiles.basePackages ++ (with pkgs; [

    # Proton GE used for Steam
    # Probably won't work on my VM without extra configuration
    #protonup

  ]);

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/john/etc/profile.d/hm-session-vars.sh
  #
  #home.sessionVariables = {
  #  EDITOR = "nvim";

  #  #STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${config.home.homeDirectory}/.steam/root/compatibilitytools.d";
  #};

  ## Let Home Manager install and manage itself.
  #programs.home-manager.enable = true;
}
