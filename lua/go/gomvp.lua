local runner = require("go.runner")
local utils = require("go.utils")
local log = utils.log
local M = {}

function M.run(args)
  require("go.install").install('gomvp')
  args = args or {}

  local input = vim.ui.input

  vim.ui.input = _GO_NVIM_CFG.go_input()
  local cmd = { "gomvp" }
  local old_mod = require('go.ts.go').get_module_at_pos()
  if old_mod == nil then
    if #args == 0 then
      utils.warn("please provide a module name or put cursor on a module name")
      return
    end
    old_mod = args[1]
  end
  local new_module
  if #args == 2 then
    new_module = args[2]
  else
    new_module = input({
      prompt = "new module name: ",
      default = old_mod,
      on_confirm = function(inp)
      new_module = inp
    end})
  end
  vim.list_extend(cmd, { old_mod, new_module })
  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        utils.restart()
      end)
    end,
  }
  log('running', cmd)
  runner.run(cmd, opts)
  return cmd, opts
end

return M
