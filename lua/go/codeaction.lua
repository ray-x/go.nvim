local utils = require('go.utils')
local log = utils.log
local api = vim.api
-- ONLY SUPPORT GOPLS

local M = {}

local function range_args()

  local vfn = vim.fn
  if vim.list_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    log('v mode required')
    return
  end
  -- get visual selection
  local start_lnum, start_col= unpack(api.nvim_buf_get_mark(0, '<'))
  local end_lnum, end_col = unpack(api.nvim_buf_get_mark(0, '>'))
  if end_col == 2^31 - 1 then
    end_col = vfn.strdisplaywidth(vfn.getline(end_lnum))-1
  end
  log(start_lnum, start_col, end_lnum, end_col)

  local params = vim.lsp.util.make_range_params()
  params.range ={
      start = {
        start_lnum - 1,
        start_col,
      },
      ['end'] = {
        end_lnum - 1,
        end_col,
      },
  }
  return params
end
function M.run_range_code_action(t)
  local context = {}
  t = t or {}
  -- context.diagnostics = vim.diagnostic.get()
  local bufnr = vim.api.nvim_get_current_buf()
  t.range = t.range or range_args().range

  local original_select = vim.ui.select
  local original_input = vim.ui.input

  vim.ui.select = _GO_NVIM_CFG.go_select()
  vim.ui.input = _GO_NVIM_CFG.go_input()
  vim.lsp.buf.code_action({
    context = context,
    range = t.range,
  })

  log('range codeaction', t, context)
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
