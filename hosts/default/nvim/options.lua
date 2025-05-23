vim.g.mapleader = " "
vim.g.maplocalleader = " "

print("Leader set: options.lua")

vim.o.clipboard = 'unnamedplus'

vim.o.number = true
vim.o.relativenumber = true

vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

vim.o.smartindent = true

vim.o.wrap = false

vim.o.updatetime = 50

vim.o.termguicolors = true

vim.o.mouse = 'a'

vim.o.hlsearch = false
vim.o.incsearch = true

vim.o.scrolloff = 8
vim.o.signcolumn = 'yes'

-- Put a visual line at 80 spaces (helps keep lines short)
--vim.o.colorcolumn = "80"
