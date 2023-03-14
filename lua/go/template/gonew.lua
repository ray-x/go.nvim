local tpleval = require('go.template').template_eval
local util = require('go.utils')
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
local function go_template_create(args)
  local filename = args[1] or 'main.go'
  local sep = util.sep()
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

return { new = go_template_create }
