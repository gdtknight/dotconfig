-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.cmd [[
  highlight CursorLine ctermbg=NONE guibg=NONE gui=NONE cterm=NONE
]]

vim.api.nvim_create_augroup("CursorLineTransparency", { clear = true })

vim.api.nvim_create_autocmd("ColorScheme", {
  group = "CursorLineTransparency",
  callback = function()
    vim.cmd [[highlight CursorLine guibg=NONE ctermbg=none]]
  end,
})
