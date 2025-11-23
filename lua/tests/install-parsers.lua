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

print('Installation completed, searching for compiled parsers...')

-- In treesitter main branch, parsers might be in different locations
local search_paths = {
  vim.fn.stdpath('cache') .. '/nvim-treesitter',
  vim.fn.stdpath('data') .. '/nvim-treesitter',
  vim.fn.stdpath('state') .. '/nvim-treesitter',
  install_dir,
  '~/.local/share/nvim/site',
  '~/.cache/nvim/nvim-treesitter',
}

-- Search recursively for .so files
for _, base_path in ipairs(search_paths) do
  local expanded = vim.fn.expand(base_path)
  if vim.fn.isdirectory(expanded) == 1 then
    print('Searching in: ' .. expanded)
    local so_files = vim.fn.glob(expanded .. '/**/*.so', false, true)
    if #so_files > 0 then
      print('Found .so files: ' .. vim.inspect(so_files))
      -- Copy all .so files to install_dir/parser
      for _, so_file in ipairs(so_files) do
        local filename = vim.fn.fnamemodify(so_file, ':t')
        local dest = install_dir .. '/parser/' .. filename
        print('Copying ' .. so_file .. ' to ' .. dest)
        vim.fn.system(string.format('cp "%s" "%s"', so_file, dest))
      end
    end
  end
end

-- Also look for queries
local queries_found = false
for _, base_path in ipairs(search_paths) do
  local expanded = vim.fn.expand(base_path)
  local queries_path = expanded .. '/queries/go'
  if vim.fn.isdirectory(queries_path) == 1 then
    print('Found queries in: ' .. queries_path)
    vim.fn.system(string.format('cp -r "%s" "%s/"', queries_path, install_dir .. '/queries'))
    queries_found = true
    break
  end
end

-- If queries not found, copy from nvim-treesitter source
if not queries_found then
  print('Copying queries from nvim-treesitter source...')
  local ts_queries = vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/nvim-treesitter/queries/go')
  if vim.fn.isdirectory(ts_queries) == 1 then
    vim.fn.system(string.format('cp -r "%s" "%s/"', ts_queries, install_dir .. '/queries'))
  end
end

-- Verify installation
print("\nVerifying parser installation...")
local parser_dir = install_dir .. '/parser'
local queries_dir = install_dir .. '/queries/go'

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
  local files = vim.fn.readdir(queries_dir)
  print('Query files: ' .. vim.inspect(files))
else
  print('WARNING: Queries directory does not exist!')
end

-- Try to load the parser
for _, parser in ipairs(parsers) do
  local ok, lang = pcall(vim.treesitter.language.add, parser)
  if ok then
    print("✓ Parser " .. parser .. " language added")
  else
    print("✗ Parser " .. parser .. " language failed: " .. tostring(lang))
  end
end

print('Parser installation complete!')