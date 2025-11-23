#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append(os.getenv('NVIM_TS_DIR'))
vim.opt.runtimepath:append('.')

local parsers = { 'go' }
for i = 1, #_G.arg do
  parsers[#parsers + 1] = _G.arg[i] ---@type string
end

require('nvim-treesitter').install(parsers, { force = true }):wait(1800000) -- wait max. 30 minutes
