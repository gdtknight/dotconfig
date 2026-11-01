-- Variables to store the original settings
local M = {}

-- Original settings
local original_settings = {
  expandtab = vim.o.expandtab,
  tabstop = vim.o.tabstop,
  shiftwidth = vim.o.shiftwidth,
}

-- Alternate settings
local alternate_settings = {
  expandtab = false,
  tabstop = 4,
  shiftwidth = 4,
}

local function settings_match(original, current)
  return original.expandtab == current.expandtab
    and original.tabstop == current.tabstop
    and original.shiftwidth == current.shiftwidth
end

local function toggle_indent_settings()
  local current_settings = {
    expandtab = vim.o.expandtab,
    tabstop = vim.o.tabstop,
    shiftwidth = vim.o.shiftwidth,
  }

  local status_string = "42format "
  if settings_match(original_settings, current_settings) then
    -- Switch to alternate settings
    vim.o.expandtab = alternate_settings.expandtab
    vim.o.tabstop = alternate_settings.tabstop
    vim.o.shiftwidth = alternate_settings.shiftwidth
    status_string = status_string
      .. "on - expandtab: "
      .. tostring(vim.o.expandtab)
      .. ", tabstop: "
      .. vim.o.tabstop
      .. ", shiftwidth: "
      .. vim.o.shiftwidth
  else
    -- Switch back to original settings
    vim.o.expandtab = original_settings.expandtab
    vim.o.tabstop = original_settings.tabstop
    vim.o.shiftwidth = original_settings.shiftwidth
    status_string = status_string
      .. "off - expandtab: "
      .. tostring(vim.o.expandtab)
      .. ", tabstop: "
      .. vim.o.tabstop
      .. ", shiftwidth: "
      .. vim.o.shiftwidth
  end

  print(status_string)
end

-- Map F3 key to toggle the indent settings
vim.api.nvim_create_user_command("Toggle42format", toggle_indent_settings, {})
vim.api.nvim_set_keymap("n", "<F3>", ":Toggle42format<CR>", { noremap = true, silent = true })

return M
