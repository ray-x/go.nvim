local utils = require("go.utils")
local log = utils.log

-- ONLY SUPPORT GOPLS

local M = {}

function M.run_action()
  local guihua = utils.load_plugin("guihua.lua", "guihua.gui")

  local original_select = vim.ui.select
  if guihua then
    vim.ui.select = require("guihua.gui").select
  end
  log("codeaction")

  vim.lsp.buf.code_action()

  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

return M
