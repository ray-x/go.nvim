local utils = require('go.utils')
local log = utils.log
local api = vim.api
-- ONLY SUPPORT GOPLS

local M = {}

local function range_mark(t)
  local vfn = vim.fn
  if vim.list_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    log('v mode required')
    return
  end
  -- get visual selection
  local start_lnum, start_col = unpack(api.nvim_buf_get_mark(0, '<'))
  local end_lnum, end_col = unpack(api.nvim_buf_get_mark(0, '>'))
  if end_col == 2 ^ 31 - 1 then
    end_col = #vfn.getline(end_lnum) - 1   -- TODO: check nerdfonts, emoji etc?
  end
  -- reverse select
  if end_lnum < start_lnum or (start_lnum == end_lnum and start_col < end_col) then
    start_lnum, end_lnum = end_lnum, start_lnum
    start_col, end_col = end_col, start_col
  end

  return {
    ['start'] = { start_lnum, start_col },
    ['end'] = { end_lnum, end_col },
  }
end

function M.run_code_action(t)
  t = t or { range = 0 }
  log('run_code_action', t)

  local original_select = vim.ui.select
  local original_input = vim.ui.input
  vim.ui.select = _GO_NVIM_CFG.go_select()
  vim.ui.input = _GO_NVIM_CFG.go_input()

  if t.range ~= 0 then
    local range = range_mark(t)
    log('range', range)
    vim.lsp.buf.code_action({ range = range })
  else
    -- nvim 0.10 will handle range select
    vim.lsp.buf.code_action()
  end
  vim.defer_fn(function()
    vim.ui.select = original_select
    vim.ui.input = original_input
  end, 1000)
end

return M
