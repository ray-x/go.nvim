local M = {}
local treesitter_go_url = 'https://github.com/tree-sitter/tree-sitter-go'
local treesitter_queries_go_url = 'https://github.com/neovim-treesitter/nvim-treesitter-queries-go'
local install_dir = vim.fn.stdpath('data') .. '/site'

---Check if the given parsers are installed
---@param parsers string[] List of parser names to check
---@return boolean result if all parsers are installed, false otherwise
---@return nil|string[] List of missing parsers if any
M.are_parsers_installed = function(parsers)
  -- Read from site/parsers/*.{so,dylib,dll} to get the list of installed parsers
  -- and remove the path and extension to get the parser names
  local installed_parsers = vim.fn.globpath(vim.fn.stdpath('data') .. '/site/parser', '*.{so,dylib,dll}', true, true)
  local missing_parsers = {}
  for i, parser in ipairs(installed_parsers) do
    installed_parsers[i] = vim.fn.fnamemodify(parser, ':t:r')
  end
  for _, parser in ipairs(parsers) do
    if not vim.list_contains(installed_parsers, parser) then
      table.insert(missing_parsers, parser)
    end
  end
  if #missing_parsers > 0 then
    return false, missing_parsers
  end
  return true, nil
end

local download_and_install_grammar = function()
  -- get tmp dir
  local tmp_dir = vim.fn.tempname()
  local dl_dir = vim.fs.joinpath(tmp_dir, 'tree-sitter-queries-go')

  if vim.fn.isdirectory(dl_dir) == 1 then
    -- Clean up any existing build
    if vim.fn.has('win32') == 1 then
      vim.fn.system('rmdir /s /q ' .. dl_dir)
    else
      vim.fn.system('rm -rf ' .. dl_dir)
    end
  end

  -- Clone the tree-sitter-go repository
  print('Cloning tree-sitter-queries-go...')
  local clone_result = vim.fn.system(string.format('git clone --depth 1 ' .. treesitter_queries_go_url .. '  "%s" 2>&1', dl_dir))
  print(clone_result)

  if vim.fn.isdirectory(vim.fs.joinpath(dl_dir, 'queries')) ~= 1 then
    print('ERROR: Failed to clone tree-sitter-queries-go')
    return false
  end

  local system_calls = {}
  if vim.fn.has('win32') == 1 then
    system_calls[#system_calls + 1] = {
      description = 'Creating queries directory',
      cmd = string.format('mkdir "%s\\queries\\go"', install_dir),
    }
    system_calls[#system_calls + 1] = {
      description = 'Copying queries',
      cmd = string.format('xcopy "%s\\queries" "%s\\queries\\go" /E /I /Y', dl_dir, install_dir),
    }
  else
    system_calls[#system_calls + 1] = {
      description = 'Creating queries directory',
      cmd = string.format('mkdir -p "%s/queries/go"', install_dir),
    }
    system_calls[#system_calls + 1] = {
      description = 'Copying queries',
      cmd = string.format('cp -r "%s/queries" "%s/queries/go"', dl_dir, install_dir),
    }
  end
  for _, call in ipairs(system_calls) do
    print(call.description .. '...')
    local result = vim.fn.system(call.cmd .. ' 2>&1')
    print(result)
    if vim.v.shell_error ~= 0 then
      print('ERROR: ' .. call.description .. ' failed')
      return false
    end
  end
end

local download_compile_and_install_parser = function()
  -- get tmp dir
  local tmp_dir = vim.fn.tempname()
  local dl_dir = vim.fs.joinpath(tmp_dir, 'tree-sitter-go')

  if vim.fn.isdirectory(dl_dir) == 1 then
    -- Clean up any existing build
    if vim.fn.has('win32') == 1 then
      vim.fn.system('rmdir /s /q ' .. dl_dir)
    else
      vim.fn.system('rm -rf ' .. dl_dir)
    end
  end

  -- Clone the tree-sitter-go repository
  print('Cloning tree-sitter-go...')
  local clone_result = vim.fn.system(string.format('git clone --depth 1 ' .. treesitter_go_url .. '  "%s" 2>&1', dl_dir))
  print(clone_result)

  if vim.fn.isdirectory(dl_dir .. '/src') ~= 1 then
    print('ERROR: Failed to clone tree-sitter-go')
    return false
  end

  -- Compile the parser
  print('Compiling parser...')
  local parser_c = dl_dir .. '/src/parser.c'
  local scanner_c = dl_dir .. '/src/scanner.c'
  local output_so = install_dir .. '/parser/go.so'

  local sources = parser_c
  if vim.fn.filereadable(scanner_c) == 1 then
    sources = sources .. ' ' .. scanner_c
  end

  local compile_cmd = string.format('cc -o "%s" -I"%s/src" %s -shared -Os -fPIC 2>&1', output_so, dl_dir, sources)

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

M.install_parsers_and_grammars = function()
  local install_dir = vim.fn.stdpath('data') .. '/site'
  vim.fn.mkdir(vim.fs.joinpath(install_dir, 'parser'), 'p')
  vim.fn.mkdir(vim.fs.joinpath(install_dir, 'queries'), 'p')

  local success, _ = M.are_parsers_installed({ 'go' })
  if success then
    return true
  end
  if not download_compile_and_install_parser() then
    return false
  end
  if not download_and_install_grammar() then
    return false
  end
  return true
end

return M
