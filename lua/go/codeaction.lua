local utils = require('go.utils')
local log = utils.log
local api = vim.api
-- ONLY SUPPORT GOPLS

local M = {}
function M.run_range_code_action(t)
  local context = {}
  t = t or {}
  context.diagnostics = vim.diagnostic.get()

  local bufnr = vim.api.nvim_get_current_buf()

  local original_select = vim.ui.select
  local original_input = vim.ui.input

  vim.ui.select = _GO_NVIM_CFG.go_select()
  vim.ui.input = _GO_NVIM_CFG.go_input()
  vim.lsp.buf.code_action({
    context = context,
    range = t.range,
  })
  vim.defer_fn(function()
    vim.ui.select = original_select
    vim.ui.input = original_input
  end, 1000)
end

function M.run_code_action()
  local original_select = vim.ui.select
  local original_input = vim.ui.input
  vim.ui.select = _GO_NVIM_CFG.go_select()
  vim.ui.input = _GO_NVIM_CFG.go_input()
  log('codeaction')

  if vim.api.nvim_get_mode().mode ~= 'v' then
    vim.lsp.buf.code_action()
  else
    vim.lsp.buf.range_code_action()
  end

  vim.defer_fn(function()
    vim.ui.select = original_select
    vim.ui.input = original_input
  end, 1000)
end

return M
