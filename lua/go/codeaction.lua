local utils = require("go.utils")
local log = utils.log

-- ONLY SUPPORT GOPLS

local M = {}

function M.run_action()
  local guihua = utils.load_plugin("guihua.lua", "guihua.gui")

  local original_select = vim.ui.select
  local original_input = vim.ui.input
  if guihua then
    vim.ui.select = require("guihua.gui").select
    vim.ui.input = require("guihua.input").input
  end
  log("codeaction")

  if vim.api.nvim_get_mode().mode ~= "v" then
    vim.lsp.buf.code_action()
  else
    vim.lsp.buf.range_code_action()
  end

  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)

  vim.defer_fn(function()
    vim.ui.input = original_input
  end, 10000)
end

return M
