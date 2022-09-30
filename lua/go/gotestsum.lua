local runner = require("go.runner")
local utils = require("go.utils")
local M = {}

function M.watch(args)
  args = args or {}

  local cmd = { "gotestsum",  "--watch" }
  vim.list_extend(cmd, args)

  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        utils.restart()
      end)
    end,
  }
  runner.run(cmd, opts)
  return cmd, opts
end

return M
