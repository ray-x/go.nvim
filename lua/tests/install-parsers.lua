#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append('.')

local install_dir = vim.fn.stdpath('data') .. '/site'
print('Installing to: ' .. install_dir)

-- Create directories if they don't exist
vim.fn.mkdir(install_dir .. '/parser', 'p')
vim.fn.mkdir(install_dir .. '/queries', 'p')

vim.opt.rtp:append('.')
vim.cmd('runtime! plugin/go')
local ts = require('go.treesitter')
if not ts.are_parsers_installed({ 'go' }) then
  print('go.so not found, attempting manual compilation...')
  if not ts.install_parsers_and_grammars() then
    os.exit(1)
  end
end

print('\n✓ Parser installation complete!')
