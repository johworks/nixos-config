vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.o.clipboard = 'unnamedplus'

-- enable abs line numbers
vim.o.number = true
-- vim.o.relativenumber = true

-- Shows stuff like git signs (~ means edited, etc.) to left of line #s
vim.o.signcolumn = 'yes'

-- How tabs are DISPLAYED
vim.o.tabstop = 4

-- Affects << and >>
vim.o.shiftwidth = 4

-- idle time (ms) before tiggering certain options (default: 4000)
vim.o.updatetime = 300

-- enables 24-bit RGB color support
vim.o.termguicolors = true

-- enables mouse support in all modes
vim.o.mouse = 'a'
