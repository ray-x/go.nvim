local runner = require("go.runner")
local utils = require("go.utils")
local vfn = vim.fn
local M = {}

function M.run(args)
  args = args or {}
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row - 1, col

  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  line = line:gsub("^%s+", "") -- lstrip
  line = line:gsub("%s+", " ")  -- combine spaces
  line = vim.split(line, " ")
  utils.log(line)
  local fn = vfn.expand('%:p:f')
  local cmd = { "go-enum", '-f', fn }
  local new_name = vfn.expand('%:p:r') .. "_enum.go"

  vim.list_extend(cmd, args)
  local opts = {
    update_buffer = true,
    on_exit = function()
      vim.schedule(function()
        -- utils.restart()
        vim.cmd('e ' .. new_name)

      end)
    end,
  }
  runner.run(cmd, opts)
  return cmd, opts
end

return M
