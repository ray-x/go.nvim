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

-- Use synchronous install and capture output
local install = require('nvim-treesitter.install')
for _, parser in ipairs(parsers) do
  print('Installing parser: ' .. parser)
  local success, err = pcall(function()
    install.update(parser)
  end)
  if not success then
    print('Installation error: ' .. tostring(err))
  end
end

-- Wait a bit for compilation to complete
vim.wait(5000, function() return false end)

print('Installation completed, searching for go parser...')

-- Check all possible locations
local all_locations = {
  vim.fn.stdpath('cache') .. '/nvim-treesitter',
  vim.fn.stdpath('data') .. '/nvim-treesitter',
  vim.fn.stdpath('data') .. '/site',
  '/tmp',
}

for _, root in ipairs(all_locations) do
  print('\nSearching in: ' .. root)
  if vim.fn.isdirectory(root) == 1 then
    -- Use find command to locate go.so
    local result = vim.fn.system(string.format('find "%s" -name "go.so" 2>/dev/null', root))
    if result ~= '' then
      print('Found go.so via find: ' .. result)
      local files = vim.split(result, '\n', { trimempty = true })
      for _, file in ipairs(files) do
        local dest = install_dir .. '/parser/go.so'
        print('Copying ' .. file .. ' to ' .. dest)
        vim.fn.system(string.format('cp "%s" "%s"', file, dest))
      end
    end
    
    -- Also check for the build directory
    local build_result = vim.fn.system(string.format('find "%s" -type d -name "tree-sitter-go" 2>/dev/null', root))
    if build_result ~= '' then
      print('Found tree-sitter-go directories: ' .. build_result)
      local dirs = vim.split(build_result, '\n', { trimempty = true })
      for _, dir in ipairs(dirs) do
        print('Contents of ' .. dir .. ':')
        local ls_result = vim.fn.system(string.format('ls -la "%s" 2>/dev/null', dir))
        print(ls_result)
        
        -- Try to manually compile if source exists
        if vim.fn.filereadable(dir .. '/src/parser.c') == 1 then
          print('Found parser.c, attempting manual compilation...')
          local compile_cmd = string.format(
            'cc -o "%s/go.so" -I"%s/src" "%s/src/parser.c" -shared -Os -lstdc++ -fPIC 2>&1',
            install_dir .. '/parser',
            dir,
            dir
          )
          print('Compile command: ' .. compile_cmd)
          local compile_result = vim.fn.system(compile_cmd)
          print('Compile result: ' .. compile_result)
        end
      end
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