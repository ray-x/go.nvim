local runner = require("go.runner")
local M = {}

function M.run(args)
  for i, arg in ipairs(args) do
    local m = string.match(arg, "^https?://(.*)$") or arg
    table.remove(args, i)
    table.insert(args, i, m)
  end
  local cmd = { "go", "get" }
  vim.list_extend(cmd, args)
  runner.run(cmd)
end

return M
