local runner = require("go.runner")
local utils = require("go.utils")
local M = {}

-- args: tidy or vendor
function M.run(...)
  local args = { ... }
  local cmd = { "go", "mod" }
  vim.list_extend(cmd, args)
  local opts = {
    after = function()
      vim.schedule(function()
        utils.restart()
      end)
    end,
  }
  runner.run(cmd, opts)
end

return M
