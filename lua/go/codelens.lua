local utils = require("go.utils")
local log = utils.log
local codelens = require("vim.lsp.codelens")
local api = vim.api

local M = {}

function M.setup()
  vim.cmd("highlight default link LspCodeLens WarningMsg")
  vim.cmd("highlight default link LspCodeLensText WarningMsg")
  vim.cmd("highlight default link LspCodeLensTextSign LspCodeLensText")
  vim.cmd("highlight default link LspCodeLensTextSeparator Boolean")

  vim.cmd("augroup go.codelenses")
  vim.cmd("  autocmd!")
  vim.cmd('autocmd BufEnter,CursorHold,InsertLeave <buffer> lua require("go.codelens").refresh()')
  vim.cmd("augroup end")
end

function M.run_action()
  local guihua = utils.load_plugin("guihua.lua", "guihua.gui")
  local original_select = vim.ui.select

  if guihua then
    vim.ui.select = require("guihua.gui").select
  end

  codelens.run()
  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

function M.refresh()
  if _GO_NVIM_CFG.lsp_codelens == false or not require("go.lsp").codelens_enabled() then
    return
  end
  vim.lsp.codelens.refresh()
end

return M
