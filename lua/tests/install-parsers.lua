#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append('../nvim-treesitter')
vim.opt.runtimepath:append('.')

local parsers = { 'go' }

local install_dir = vim.fn.stdpath('data') .. '/site'
print('Installing to: ' .. install_dir)

-- Create directories if they don't exist
vim.fn.mkdir(install_dir .. '/parser', 'p')
vim.fn.mkdir(install_dir .. '/queries', 'p')

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

print('Installation completed, checking build artifacts...')

-- Check the nvim-treesitter cache directory where parsers are actually built
local cache_dir = vim.fn.stdpath('cache') .. '/nvim-treesitter'
print('Cache directory: ' .. cache_dir)

if vim.fn.isdirectory(cache_dir) == 1 then
  local cache_contents = vim.fn.glob(cache_dir .. '/**', false, true)
  print('Cache contents: ' .. vim.inspect(cache_contents))
end

-- Try to find where the parser was actually compiled
local possible_locations = {
  cache_dir .. '/parser',
  install_dir .. '/parser',
  vim.fn.stdpath('data') .. '/parser',
}

for _, loc in ipairs(possible_locations) do
  if vim.fn.isdirectory(loc) == 1 then
    local files = vim.fn.glob(loc .. '/*', false, true)
    if #files > 0 then
      print('Found parser files in: ' .. loc)
      print('Files: ' .. vim.inspect(files))
      -- Copy to install_dir if needed
      if loc ~= install_dir .. '/parser' then
        print('Copying parsers to install directory...')
        vim.fn.system(string.format('cp -r %s/* %s/', loc, install_dir .. '/parser'))
      end
    end
  end
end

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
    print('ERROR: No parser files found after installation!')
    os.exit(1)
  end
else
  print('ERROR: Parser directory does not exist!')
  os.exit(1)
end

if vim.fn.isdirectory(queries_dir) == 1 then
  local dirs = vim.fn.readdir(queries_dir)
  print('Query subdirs: ' .. vim.inspect(dirs))
else
  print('WARNING: Queries directory does not exist - copying from nvim-treesitter')
  -- Copy queries from nvim-treesitter source
  local ts_queries = '../nvim-treesitter/queries'
  if vim.fn.isdirectory(ts_queries) == 1 then
    vim.fn.system(string.format('cp -r %s/* %s/', ts_queries, queries_dir))
  end
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