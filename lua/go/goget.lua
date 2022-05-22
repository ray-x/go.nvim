local runner = require("go.runner")
local utils = require("go.utils")
local M = {}

function M.run(args)
  for i, arg in ipairs(args) do
    local m = string.match(arg, "^https?://(.*)$") or arg
    table.remove(args, i)
    table.insert(args, i, m)
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row - 1, col

  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  local cmd = { "go", "get" }
  vim.list_extend(cmd, args)
  line = line:gsub("%s+", "")
  line = line:gsub('"', "")
  if string.find(line, "%a+%.%a+/%a+/%a+") then
    -- the cursor is on line of package URL e.g. github.com/abc/pkg
    table.insert(cmd, line)
  else
    if #args == 0 then
      table.insert(cmd, "./...")
    end
  end
  local opts = {
    after = function()
      vim.schedule(function()
        utils.restart()
      end)
    end,
  }
  runner.run(cmd, opts)
  return cmd, opts
end

return M
