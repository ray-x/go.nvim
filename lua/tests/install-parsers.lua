#!/usr/bin/env -S nvim -l
vim.opt.runtimepath:append('../nvim-treesitter')
vim.opt.runtimepath:append('.')

local install_dir = vim.fn.stdpath('data') .. '/site'
print('Installing to: ' .. install_dir)

-- Create directories if they don't exist
vim.fn.mkdir(install_dir .. '/parser', 'p')
vim.fn.mkdir(install_dir .. '/queries', 'p')

-- Manual compilation approach
local function compile_parser()
  local build_dir = '/tmp/tree-sitter-go'
  
  -- Clean up any existing build
  vim.fn.system('rm -rf ' .. build_dir)
  
  -- Clone the tree-sitter-go repository
  print('Cloning tree-sitter-go...')
  local clone_result = vim.fn.system(string.format(
    'git clone --depth 1 https://github.com/tree-sitter/tree-sitter-go.git %s 2>&1',
    build_dir
  ))
  print(clone_result)
  
  if vim.fn.isdirectory(build_dir .. '/src') ~= 1 then
    print('ERROR: Failed to clone tree-sitter-go')
    return false
  end
  
  -- Compile the parser
  print('Compiling parser...')
  local parser_c = build_dir .. '/src/parser.c'
  local scanner_c = build_dir .. '/src/scanner.c'
  local output_so = install_dir .. '/parser/go.so'
  
  local sources = parser_c
  if vim.fn.filereadable(scanner_c) == 1 then
    sources = sources .. ' ' .. scanner_c
  end
  
  local compile_cmd = string.format(
    'cc -o "%s" -I"%s/src" %s -shared -Os -fPIC 2>&1',
    output_so,
    build_dir,
    sources
  )
  
  print('Compile command: ' .. compile_cmd)
  local compile_result = vim.fn.system(compile_cmd)
  print('Compile output: ' .. compile_result)
  
  -- Check if compilation succeeded
  if vim.fn.filereadable(output_so) == 1 then
    print('✓ Successfully compiled go.so')
    return true
  else
    print('✗ Failed to compile go.so')
    return false
  end
end

-- Try nvim-treesitter first
print('Attempting nvim-treesitter installation...')
vim.opt.rtp:append(install_dir)

local ok, _ = pcall(function()
  require('nvim-treesitter').setup({
    install_dir = install_dir,
  })
  
  local install = require('nvim-treesitter.install')
  install.update('go')
  vim.wait(5000, function() return false end)
end)

-- Check if nvim-treesitter installation worked
local go_so_path = install_dir .. '/parser/go.so'
if vim.fn.filereadable(go_so_path) ~= 1 then
  print('nvim-treesitter installation did not create go.so, trying manual compilation...')
  if not compile_parser() then
    print('ERROR: Manual compilation also failed')
    os.exit(1)
  end
end

-- Copy queries from nvim-treesitter source
print('\nCopying queries...')
local ts_queries_paths = {
  vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/nvim-treesitter/queries/go'),
  '../nvim-treesitter/queries/go',
  '/tmp/tree-sitter-go/queries',
}

local queries_copied = false
for _, ts_queries in ipairs(ts_queries_paths) do
  if vim.fn.isdirectory(ts_queries) == 1 then
    print('Copying queries from: ' .. ts_queries)
    vim.fn.system(string.format('cp -r "%s" "%s/"', ts_queries, install_dir .. '/queries'))
    queries_copied = true
    break
  end
end

if not queries_copied then
  print('WARNING: Could not find queries directory')
end

-- Verify installation
print("\nVerifying parser installation...")
local parser_dir = install_dir .. '/parser'
local queries_dir = install_dir .. '/queries/go'

if vim.fn.isdirectory(parser_dir) == 1 then
  local files = vim.fn.readdir(parser_dir)
  print('Parser files: ' .. vim.inspect(files))
  
  local go_so_exists = vim.fn.filereadable(parser_dir .. '/go.so') == 1
  print('go.so exists: ' .. tostring(go_so_exists))
  print('go.so size: ' .. vim.fn.getfsize(parser_dir .. '/go.so') .. ' bytes')
  
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
  print('WARNING: Queries directory does not exist - tests may fail')
end

print('\n✓ Parser installation complete!')