local tpleval = require('go.template').template_eval
local util = require('go.utils')
local uv = vim.loop or vim.uv
local log = util.log

local go_examples = {
  'appengine-hello',
  'hello',
  'helloserver',
}
local tpl_main = [[
package $(pkg)

import "fmt"

func $(pkg)() {
\tfmt.Println("hello world")
}
]]

local tpl_main_test = [[
package $(pkg)

import (
\t"testing"
)

func Test$(funname)(t *testing.T) {
\tt.Error("not implemented")
}
]]

local current_file = vim.fn.resolve(vim.fn.expand('<sfile>'))
local get_pkg = require('go.package').pkg_from_path

local function handleoutput(output)
  -- Pattern to match the expected initialization format and extract the folder name
  vim.validate({ output = { output, 'string' } })
  local folder_name_pattern = 'initialized .- in (.+)%s*$'
  local folder_path = output:match(folder_name_pattern)

  if not folder_path then
    util.warn('Unable to extract folder name from output or output format is unexpected.')
    return
  end
  log('output: ', output, folder_path)
  -- Check if the folder is created
  local stat = uv.fs_stat(folder_path)
  if stat and stat.type == 'directory' then
    -- Change the working directory to the new folder
    vim.cmd('cd ' .. vim.fn.fnameescape(folder_path))

    local cwd = uv.cwd()

    local go_files = vim.fn.globpath(uv.cwd(), '*.go', false, true)
    local target_file

    -- Prioritize 'hello.go' or 'main.go' if they exist
    for _, file in ipairs(go_files) do
      if file:match('hello%.go$') or file:match('main%.go$') then
        target_file = file
        break
      end
    end
    target_file = target_file or go_files[1]
    log('generated files', go_files, target_file)

    if target_file then
      -- Open the file in Neovim
      vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
    else
      util.warn('No .go files found in the directory: ' .. folder_path)
    end
  else
    util.warn('Directory not created or not found: ' .. folder_path)
  end
end

-- create go project from go/examples
-- use `gonew` cli tool:  gonew srcmod[@version] [dstmod [dir]]
local gonew = function(args)
  local urlbase = 'golang.org/x/example/'
  local url = urlbase .. args[1]
  local cmd = { 'gonew', url }
  if args[2] then
    table.insert(cmd, args[2])
    if args[3] then
      table.insert(cmd, args[3])
    end
  end
  local runner = require('go.runner')
  local utils = require('go.utils')
  util.log(cmd)
  local opts = {
    on_exit = function(code, signal, data)
      log(code, signal, data)
      vim.validate({ data = { data, 'string' } }) -- it should be string separated by \n
      if code ~= 0 then
        util.warn('gonew failed with:' .. vim.inspect(data) .. 'signal ' .. tonumber(signal or 0))
        return
      end

      vim.schedule(function()
        utils.info(string.format('% success', vim.inspect(cmd)))
        handleoutput(data)
      end)
      return data
    end,
  }
  if args[3] then
    opts.cwd = args[3]
  end
  runner.run(cmd, opts)
end
local function go_template_create(args)
  local filename = args[1] or 'main.go'
  local sep = util.sep()
  if args[1] and vim.tbl_contains(go_examples, args[1]) then
    gonew(args)
    return
  end
  local package_name = get_pkg()
  if vim.fn.empty(package_name) == 1 or vim.fn.empty(package_name[1]) == 1 then
    package_name = 'main'
  else
    if package_name[1]:find('cannot find') then
      package_name = 'main'
    else
      package_name = package_name[1]
      local pkgs = vim.split(package_name, sep) -- win?
      package_name = pkgs[#pkgs]
    end
  end
  util.log(package_name)
  local root_dir = vim.fn.fnamemodify(current_file, ':h:h:h')

  local text
  if string.find(filename, '_test.go$') then
    -- get the function name
    local f = vim.split(filename, '_')[1] or 'main'
    f = vim.split(f, sep) -- win?
    f = f[#f]
    f = string.upper(string.sub(f, 1, 1)) .. string.sub(f, 2)
    _, text = tpleval(tpl_main_test, { pkg = package_name, funname = f })
  else
    _, text = tpleval(tpl_main, { pkg = package_name })
  end
  -- filename = root_dir .. sep .. filename
  vim.fn.execute('edit ' .. vim.fn.fnameescape(filename))
  text = text:gsub('\\t', '\t')
  local lines = vim.split(text, '\n')
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

return { new = go_template_create, complete = go_examples }
