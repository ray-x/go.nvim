local runner = require("go.runner")
local M = {}

-- args: tidy or vendor
function M.run(args)
  local cmd = { "go", "mod" }
  vim.list_extend(cmd, args)
  local opts = {
    after = function()
      vim.schedule(function()
        utils.restart()
	  end)
    end,
  }
  runner.run(cmd)
end

return M
