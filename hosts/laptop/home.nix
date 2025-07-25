{ config, pkgs, inputs, ... }:
let
  gruvboxPlus = import ../../modules/home/gruvbox-plus.nix { inherit pkgs; };
in 
{

  imports = [ 
    ../../modules/home/hyprland.nix
  ];


  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "john";
  home.homeDirectory = "/home/john";

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 14;
  };

  # Enable gtk (GNOME)
  gtk = {
    enable = true;
      #cursorTheme = {
      #  package = pkgs.bibata-cursors;
      #  name = "Bibata-Modern-Ice";
      #};
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3";
    };
    iconTheme = {
      package = gruvboxPlus;
      name = "GruvboxPlus";
    };
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14;
    };
  };

  # Enable qt (KDE)
  qt.enable = true;
  qt.platformTheme.name = "gtk";
  qt.style.name = "adwaita-dark";


  # Enable and configure neovim
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
        ${builtins.readFile ../../modules/home/nvim/options.lua}
        ${builtins.readFile ../../modules/home/nvim/keymaps.lua}
    '';

    # Package dependencies
    extraPackages = with pkgs; [
		# Clipboards
		xclip    # x11
		wl-clipboard   # wayland

		# LSPs
		lua-language-server
		nixd
        pyright


        # For telescope
        ripgrep
    ];

    plugins = with pkgs.vimPlugins; [

		# Add LSP support
		{
			plugin = nvim-lspconfig;
			config = toLuaFile ../../modules/home/nvim/plugin/lsp.lua;
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
			config = toLuaFile ../../modules/home/nvim/plugin/cmp.lua;
		}

		{
			plugin = telescope-nvim;
			config = toLuaFile ../../modules/home/nvim/plugin/telescope.lua;
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
			config = toLuaFile ../../modules/home/nvim/plugin/treesitter.lua;
		}

		vim-nix

    ];

  };  # End nvim configuations

	
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

  # Setup firefox; Move to it's own file soon
  programs.firefox = {
    enable = true;
    profiles.default = {

      settings = {
        "dom.security.https_only_mode" = true;  # This might break self-hosted apps
        "browser.download.panel.shown" = true;
        "identity.fxaccounts.enabled" = false;
        "signon.remeberSignons" = false;
        # Remove sponsored bs
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        # Disable snippets (Firefox promotional messages)
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        # Optional: Clean up new tab layout further
        "browser.newtabpage.activity-stream.feeds.topsites" = true;
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
        "browser.newtabpage.activity-stream.feeds.section.recommendationProvider" = false;
      };

      search.engines = {
        "Nix Packages" = {
          urls = [{
            template = "https://search.nixos.org/packages";
            params = [
              { name = "type"; value = "packages"; }
              { name = "query"; value = "{searchTerms}"; }
            ];
          }];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [ "@np" ];
        };
      };
      search.force = true;

      extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        youtube-shorts-block
        sponsorblock
        keepassxc-browser
      ];
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
  home.packages = with pkgs; [

    # Look for a new browser that doesn't steal data
    #firefox

    # Password manager
    # Not configured yet
    keepassxc

    # Icons that GTK apps (like wofi) use
    #papirus-icon-theme
    kdePackages.breeze-icons  # default used by gtk

    # Make Qt applications integrate with GNOME stylings
    adwaita-qt

    # Just some random version of python idk
    # Just use nix-shell with all your python packages
    #python311

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = 
  let 
    forest-wallpaper = builtins.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/irl/forest-3.jpg";
      sha256 = "14l56mlia6ncpc8aj15z1cdpm38f8hn14c1p1js67d3b7k6rhbnz";
    };
    nix-wallpaper = builtins.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/minimalistic/nix.png";
      sha256 = "0j5zz31fkmlkcbnj49a643vxdsvq486vf4l2r4hc6fdr43h8kzwc";
    };
  in {
    # Default wallpaper
    "Pictures/Wallpapers/forest-3.jpg".source = forest-wallpaper;
    "Pictures/Wallpapers/nix-gold.jpg".source = nix-wallpaper;

    # Manage who we trust
    ".ssh/known_hosts".text = ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
      '';
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

    QT_STYLE_OVERRIDE = "adwaita-dark";

    #STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${config.home.homeDirectory}/.steam/root/compatibilitytools.d";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
