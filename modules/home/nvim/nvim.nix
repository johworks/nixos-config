{ config, pkgs, ... }: 
{
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
        ${builtins.readFile ./options.lua}
        ${builtins.readFile ./keymaps.lua}
    '';

    # Package dependencies
    extraPackages = with pkgs; [
		# Clipboards
		xclip         # x11
		wl-clipboard  # wayland

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
			config = toLuaFile ./plugin/lsp.lua;
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
			config = toLuaFile ./plugin/cmp.lua;
		}

		{
			plugin = telescope-nvim;
			config = toLuaFile ./plugin/telescope.lua;
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
			config = toLuaFile ./plugin/treesitter.lua;
		}

		vim-nix

    ];

  };  # End nvim configuations
}
