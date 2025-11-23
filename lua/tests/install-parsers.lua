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

for _, parser in ipairs(parsers) do
  local ok = pcall(vim.treesitter.language.add, parser)
  if ok then
    print("✓ Parser " .. parser .. " successfully installed")
  else
    print("✗ Parser " .. parser .. " failed to install")
  end
end