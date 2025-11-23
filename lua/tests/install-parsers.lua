#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append('../nvim-treesitter')
vim.opt.runtimepath:append('.')

local parsers = { 'go' }
for i = 1, #_G.arg do
  parsers[#parsers + 1] = _G.arg[i] ---@type string
end

local install_dir = vim.fn.stdpath('data') .. '/site'
print('Installing to: ' .. install_dir)

-- Add install_dir to runtimepath before setup
vim.opt.rtp:append(install_dir)

require('nvim-treesitter').setup({
  -- Directory to install parsers and queries to
  install_dir = install_dir,
})

require('nvim-treesitter').install(parsers, { force = true }):wait(1800000) -- wait max. 30 minutes

-- Verify installation
print("Verifying parser installation...")
print("Install directory: " .. install_dir)

-- Check if directories exist
local parser_dir = install_dir .. '/parser'
local queries_dir = install_dir .. '/queries'
print('Parser directory exists: ' .. tostring(vim.fn.isdirectory(parser_dir) == 1))
print('Queries directory exists: ' .. tostring(vim.fn.isdirectory(queries_dir) == 1))

-- List what's in the directories
if vim.fn.isdirectory(parser_dir) == 1 then
  local files = vim.fn.glob(parser_dir .. '/*', false, true)
  print('Parser files: ' .. vim.inspect(files))
end
if vim.fn.isdirectory(queries_dir) == 1 then
  local dirs = vim.fn.glob(queries_dir .. '/*', false, true)
  print('Query subdirs: ' .. vim.inspect(dirs))
  -- Check specifically for go queries
  local go_queries = vim.fn.glob(queries_dir .. '/go/*', false, true)
  print('Go query files: ' .. vim.inspect(go_queries))
end

-- Set parser path explicitly
vim.treesitter.language.register('go', 'go')

-- Try to load the parser
for _, parser in ipairs(parsers) do
  local ok, lang = pcall(vim.treesitter.language.add, parser)
  if ok then
    print("✓ Parser " .. parser .. " language added")
    -- Try to actually load it
    local load_ok, err = pcall(vim.treesitter.language.inspect, parser)
    if load_ok then
      print("✓ Parser " .. parser .. " successfully loaded")
    else
      print("✗ Parser " .. parser .. " failed to load: " .. tostring(err))
    end
  else
    print("✗ Parser " .. parser .. " language failed: " .. tostring(lang))
  end
end