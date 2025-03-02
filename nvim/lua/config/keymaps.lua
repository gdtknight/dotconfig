-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- better up/down
vim.keymap.set("i", "jk", "<ESC>", { desc = "Return to normal mode", silent = true })

-- clear cursorline highlight
vim.keymap.set("n", "<F4>", ":highlight clear cursorline<cr>", { desc = "Clear cursorline highlight", silent = true })

-- floating terminal
local lazyterm = function()
  LazyVim.terminal(nil, { cwd = LazyVim.root() })
end

vim.keymap.set("n", "<c-\\>", lazyterm, { desc = "Terminal (Root Dir)" })
vim.keymap.set("t", "<C-\\>", "<cmd>close<cr>", { desc = "Hide Terminal" })

-- vim-tmux navigator
vim.keymap.set("n", "<C-h>", ":NvimTmuxNavigateLeft<CR>", { desc = "NvimTmuxNavigateLeft", silent = true })
vim.keymap.set("n", "<C-j>", ":NvimTmuxNavigateDown<CR>", { desc = "NvimTmuxNavigateDown", silent = true })
vim.keymap.set("n", "<C-k>", ":NvimTmuxNavigateUp<CR>", { desc = "NvimTmuxNavigateUp", silent = true })
vim.keymap.set("n", "<C-l>", ":NvimTmuxNavigateRight<CR>", { desc = "NvimTmuxNavigateRight", silent = true })

-- kubectl.nvim
vim.keymap.set("n", "<leader>k", "<cmd>lua require('kubectl').toggle()<cr>", { desc = "kubectl.nvim", silent = true })
