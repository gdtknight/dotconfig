-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.cmd([[highlight clear CursorLine]])

-- vim.cmd([[
--   Toggle42format
-- ]])

-- qmd 파일에서 venv-selector 활성화

-- vim.api.nvim_create_autocmd("FileType", {
-- 	pattern = { "python", "qmd" },
-- 	callback = function()
-- 		vim.keymap.set("n", "<leader>cv", "<cmd>VenvSelect<cr>", { desc = "Select VirtualEnv", buffer = true })
-- 	end,
-- 	desc = "Set venv-selector keymap for python and qmd",
-- })
--
-- vim.api.nvim_create_autocmd("User", {
-- 	pattern = "LazyDone",
-- 	callback = function()
-- 		local rplugin = vim.fn.stdpath("data") .. "/rplugin.vim"
-- 		if vim.fn.filereadable(rplugin) == 0 then
-- 			vim.cmd("UpdateRemotePlugins")
-- 		end
-- 	end,
-- })
