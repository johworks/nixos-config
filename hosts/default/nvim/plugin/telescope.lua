require('telescope').setup({
	extentions = {
		fzf = {
			fuzzy = true,  -- fuzzy finding
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mod = "smart_case",  -- or "ignore_case" or "respect_case"
		}
	}
})

require('telescope').load_extenson('fzf')
