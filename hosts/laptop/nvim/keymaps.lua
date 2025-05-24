-- Define all keymaps here to make sure
-- options.lua is loaded first

--vim.g.mapleader = " "

-- Telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<leader>pg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>pb', builtin.buffers, {})
vim.keymap.set('n', '<leader>ph', builtin.help_tags, {})

vim.keymap.set('n', '<C-p>', builtin.git_files, {})

-- General

-- Open the Ex menu (file explorer)
vim.keymap.set('n', '<leader>pv', vim.cmd.Ex)

-- When highlighted, move everything up/down
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Easier saving
vim.keymap.set('n', '<C-s>', ":w")

-- J now keeps cursor at the start of line
vim.keymap.set('n', 'J', "mzJ`z")

-- Keep half page jumps in the middle
vim.keymap.set('n', '<C-d>', "<C-d>zz")
vim.keymap.set('n', '<C-u>', "<C-u>zz")

-- Keep search terms in the middle
vim.keymap.set('n', 'n', "nzzzv")
vim.keymap.set('n', 'N', "Nzzzv")

-- Keep what you just copied, and pasted deleting over whatever
vim.keymap.set('x', '<leader>p', "\"_dP")

-- Copy to the system clipboard; Keep clipboard segregated
vim.keymap.set('n', '<leader>y', "\"+y")
vim.keymap.set('v', '<leader>y', "\"+y")
vim.keymap.set('n', '<leader>Y', "\"+Y")

-- Delete to void register
vim.keymap.set('n', '<leader>d', "\"_dP")
vim.keymap.set('v', '<leader>d', "\"_dP")

-- Prime says this command is terrible
vim.keymap.set('n', 'Q', "<nop>")

-- Useful tmux command for navigating projects
-- I don't use tmux yet so I'm leaving this one out
-- vim.keymap.set('n', '<C-f>', "<cmd>silent !tmux neww tmux-sessionizer<CR>")

-- LSP formatting
vim.keymap.set('n', '<leader>f', function()
    vim.lsp.buf.format()
end)

-- Quickfix list naviagation (I don't use this yet)
-- vim.keymap.set('n', '<C-k>', "<cmd>cnext<CR>zz")
-- vim.keymap.set('n', '<C-j>', "<cmd>cprev<CR>zz")
-- vim.keymap.set('n', '<leader>k', "<cmd>lnext<CR>zz")
-- vim.keymap.set('n', '<leader>j', "<cmd>lprev<CR>zz")

-- Replace the word you are on
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Make the file you're editing executable
vim.keymap.set('n', '<leader>x', "<cmd>!chmod +x %<CR>", { silent = true })
