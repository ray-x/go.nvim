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


  local module_current_line = require('go.mod').get_mod()
  -- utils.log(line)
  local cmd = { 'go', 'get' }
  vim.list_extend(cmd, args)
  if module_current_line then
    table.insert(cmd, module_current_line)
  else
    if #args == 0 then
      table.insert(cmd, './...')
    end
  end

  utils.log(cmd)

  local workfolder = utils.get_gopls_workspace_folders()[1] or vfn.getcwd()
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
