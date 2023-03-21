local runner = require('go.runner')
local utils = require('go.utils')
local vfn = vim.fn
local M = {}

function M.run(args)
  args = args or {}
  for i, arg in ipairs(args) do
    local m = string.match(arg, '^https?://(.*)$') or arg
    table.remove(args, i)
    table.insert(args, i, m)
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row - 1, col

  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  line = line:gsub('^%s+', '') -- lstrip
  line = line:gsub('%s+', ' ') -- combine spaces
  utils.log(line)
  line = vim.split(line, ' ')
  utils.log(line)
  local cmd = { 'go', 'get' }
  vim.list_extend(cmd, args)
  local pkg1 = line[1]:gsub('"', '')
  local pkg2 = ''
  if line[2] then
    pkg2 = line[2]:gsub('"', '')
  end
  utils.log(pkg1, pkg2)
  if string.find(pkg1, '%a+%.%a+/%a+/%a+') or string.find(pkg1, '%a+%.%a+/%a+') then
    -- the cursor is on line of package URL e.g. github.com/abc/pkg
    table.insert(cmd, pkg1)
  elseif string.find(pkg2, '%a+%.%a+/%a+/%a+') or string.find(pkg2, '%a+%.%a+/%a+') then
    table.insert(cmd, pkg2)
  else
    if #args == 0 then
      table.insert(cmd, './...')
    end
  end

  utils.log(cmd)

  local workfolder = vim.lsp.buf.list_workspace_folders()[1] or vfn.getcwd()
  local modfile = workfolder .. utils.sep() .. 'go.mod'
  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        -- utils.restart()
        require('go.lsp').watchFileChanged(modfile)
      end)
    end,
  }
  runner.run(cmd, opts)
  return cmd, opts
end

return M
