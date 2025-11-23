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

print('Installation completed, searching for go parser...')

-- Check the build directory specifically for go parser
local build_locations = {
  vim.fn.stdpath('cache') .. '/nvim-treesitter/tree-sitter-go',
  vim.fn.stdpath('data') .. '/nvim-treesitter/tree-sitter-go',
  install_dir .. '/parser',
  '/tmp/tree-sitter-go',
}

local go_parser_found = false

for _, location in ipairs(build_locations) do
  local expanded = vim.fn.expand(location)
  print('Checking: ' .. expanded)
  if vim.fn.isdirectory(expanded) == 1 then
    print('  Directory exists, listing contents:')
    local files = vim.fn.glob(expanded .. '/*', false, true)
    for _, file in ipairs(files) do
      print('    ' .. file)
    end
    
    -- Look for go.so specifically
    local go_so = vim.fn.glob(expanded .. '/**/go.so', false, true)
    if #go_so > 0 then
      print('  Found go.so: ' .. vim.inspect(go_so))
      for _, so_file in ipairs(go_so) do
        local dest = install_dir .. '/parser/go.so'
        print('  Copying ' .. so_file .. ' to ' .. dest)
        vim.fn.system(string.format('cp "%s" "%s"', so_file, dest))
        go_parser_found = true
      end
    end
  end
end

-- If not found, search everywhere
if not go_parser_found then
  print('\nSearching entire filesystem for go.so...')
  local search_roots = {
    vim.fn.stdpath('cache'),
    vim.fn.stdpath('data'),
    vim.fn.stdpath('state'),
    '/tmp',
  }
  
  for _, root in ipairs(search_roots) do
    local go_files = vim.fn.glob(root .. '/**/go.so', false, true)
    if #go_files > 0 then
      print('Found go.so files: ' .. vim.inspect(go_files))
      for _, so_file in ipairs(go_files) do
        local dest = install_dir .. '/parser/go.so'
        print('Copying ' .. so_file .. ' to ' .. dest)
        vim.fn.system(string.format('cp "%s" "%s"', so_file, dest))
        go_parser_found = true
      end
      break
    end
  end
end

-- Copy queries from nvim-treesitter source
print('\nCopying queries...')
local ts_queries_paths = {
  vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/nvim-treesitter/queries/go'),
  '../nvim-treesitter/queries/go',
}

for _, ts_queries in ipairs(ts_queries_paths) do
  if vim.fn.isdirectory(ts_queries) == 1 then
    print('Copying queries from: ' .. ts_queries)
    vim.fn.system(string.format('cp -r "%s" "%s/"', ts_queries, install_dir .. '/queries'))
    break
  end
end

-- Verify installation
print("\nVerifying parser installation...")
local parser_dir = install_dir .. '/parser'
local queries_dir = install_dir .. '/queries/go'

if vim.fn.isdirectory(parser_dir) == 1 then
  local files = vim.fn.readdir(parser_dir)
  print('Parser files: ' .. vim.inspect(files))
  
  -- Check specifically for go.so
  local go_so_exists = vim.fn.filereadable(parser_dir .. '/go.so') == 1
  print('go.so exists: ' .. tostring(go_so_exists))
  
  if not go_so_exists then
    print('ERROR: go.so not found!')
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
  print('ERROR: Queries directory does not exist!')
  os.exit(1)
end

print('Parser installation complete!')