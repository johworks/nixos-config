{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "john";
  home.homeDirectory = "/home/john";

  programs.neovim = 
  let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF \n${builtins.readFile file}\nEOF\n";
  in
  {
    enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Load options first
    extraLuaConfig = ''
        ${builtins.readFile ./nvim/options.lua}
        ${builtins.readFile ./nvim/keymaps.lua}
    '';

    # Package dependencies
    extraPackages = with pkgs; [
		# Clipboards
		xclip    # x11
		wl-clipboard   # wayland

		# LSPs
		lua-language-server
		nixd

        # For telescope
        ripgrep
    ];

    plugins = with pkgs.vimPlugins; [

		# Add LSP support
		{
			plugin = nvim-lspconfig;
			config = toLuaFile ./nvim/plugin/lsp.lua;
		}

		# Nice plugin to make comments better
		{
			plugin = comment-nvim;
			config = toLua "require(\"Comment\").setup()";
		}

		{
			plugin = gruvbox-nvim;
			config = "colorscheme gruvbox";
		}

		neodev-nvim

		nvim-cmp
		{
			plugin = nvim-cmp;
			config = toLuaFile ./nvim/plugin/cmp.lua;
		}

		{
			plugin = telescope-nvim;
			config = toLuaFile ./nvim/plugin/telescope.lua;
		}

		# I believe this is meant to help with performance
		# in large code bases
		telescope-fzf-native-nvim

		cmp_luasnip
		cmp-nvim-lsp

		luasnip
		friendly-snippets

		lualine-nvim
		nvim-web-devicons

		{
			plugin = (nvim-treesitter.withPlugins (p: [
				p.tree-sitter-nix
				p.tree-sitter-vim
				p.tree-sitter-bash
				p.tree-sitter-lua
				p.tree-sitter-python
			]));
			config = toLuaFile ./nvim/plugin/treesitter.lua;
		}

		vim-nix

    ];

    /*
    extraLuaConfig = ''
        ${builtins.readFile ./nvim/options.lua}
    '';
    */

  };  # End nvim configuations

	
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
	/*
    # Haven't figured this bit out yet
	knownHosts = {
		"github.com" = {
			hostNames = [ "github.com" ];
			publicKey = ''
				github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
			'';

		};
	};
	*/
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
  home.packages = with pkgs; [

    # Proton GE used for Steam
    # Probably won't work on my VM without extra configuration
    #protonup

    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

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
  home.sessionVariables = {
    EDITOR = "nvim";

    #STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${config.home.homeDirectory}/.steam/root/compatibilitytools.d";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
