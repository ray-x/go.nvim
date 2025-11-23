#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append('../nvim-treesitter')
vim.opt.runtimepath:append('.')

local parsers = { 'go' }
for i = 1, #_G.arg do
  parsers[#parsers + 1] = _G.arg[i] ---@type string
end

require('nvim-treesitter').setup({
  -- Directory to install parsers and queries to
  install_dir = vim.fn.stdpath('data') .. '/site',
})

require('nvim-treesitter').install(parsers, { force = true }):wait(1800000) -- wait max. 30 minutes


-- Verify installation
print("Verifying parser installation...")
local install_info = require('nvim-treesitter.info')
local installed = install_info.installed_parsers()
print('Installed parsers: ' .. vim.inspect(installed))

for _, parser in ipairs(parsers) do
  if vim.tbl_contains(installed, parser) then
    print("✓ Parser " .. parser .. " successfully installed")
  else
    print("✗ Parser " .. parser .. " failed to install")
  end
end