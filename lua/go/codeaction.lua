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

  local guihua = utils.load_plugin('guihua.lua', 'guihua.gui')
  if guihua then
    vim.ui.select = require('guihua.gui').select
    vim.ui.input = require('guihua.input').input
  end
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
  local guihua = utils.load_plugin('guihua.lua', 'guihua.gui')

  local original_select = vim.ui.select
  local original_input = vim.ui.input
  if guihua then
    vim.ui.select = require('guihua.gui').select
    vim.ui.input = require('guihua.input').input
  end
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
