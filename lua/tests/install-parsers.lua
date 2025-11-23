#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append('../nvim-treesitter')
vim.opt.runtimepath:append('.')

local parsers = { 'go' }

local install_dir = vim.fn.stdpath('data') .. '/site'
print('Installing to: ' .. install_dir)

-- Add install_dir to runtimepath before setup
vim.opt.rtp:append(install_dir)

require('nvim-treesitter').setup({
  -- Directory to install parsers and queries to
  install_dir = install_dir,
})

print('Starting parser installation...')
local ok, result = pcall(function()
  return require('nvim-treesitter').install(parsers, { force = true }):wait(1800000)
end)

if not ok then
  print('Installation failed: ' .. tostring(result))
  os.exit(1)
end

print('Installation completed, verifying...')

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
  local files = vim.fn.readdir(parser_dir)
  print('Parser files: ' .. vim.inspect(files))
  if #files == 0 then
    print('ERROR: No parser files found!')
    os.exit(1)
  end
else
  print('ERROR: Parser directory does not exist!')
  os.exit(1)
end

if vim.fn.isdirectory(queries_dir) == 1 then
  local dirs = vim.fn.readdir(queries_dir)
  print('Query subdirs: ' .. vim.inspect(dirs))
  -- Check specifically for go queries
  if vim.fn.isdirectory(queries_dir .. '/go') == 1 then
    local go_queries = vim.fn.readdir(queries_dir .. '/go')
    print('Go query files: ' .. vim.inspect(go_queries))
  end
else
  print('ERROR: Queries directory does not exist!')
  os.exit(1)
end

-- Try to load the parser
for _, parser in ipairs(parsers) do
  local ok, lang = pcall(vim.treesitter.language.add, parser)
  if ok then
    print("✓ Parser " .. parser .. " language added")
  else
    print("✗ Parser " .. parser .. " language failed: " .. tostring(lang))
    os.exit(1)
  end
end

print('All parsers installed successfully!')