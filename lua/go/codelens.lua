local utils = require('go.utils')
local codelens = require('vim.lsp.codelens')

local M = {}

function M.setup()
  utils.log('enable codelens')
  vim.cmd('highlight default link LspCodeLens WarningMsg')
  vim.cmd('highlight default link LspCodeLensText WarningMsg')
  vim.cmd('highlight default link LspCodeLensTextSign LspCodeLensText')
  vim.cmd('highlight default link LspCodeLensTextSeparator Boolean')

  local group = vim.api.nvim_create_augroup('gonvim__codelenses', {})
  vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'CursorHoldI', 'InsertLeave' }, {
    group = vim.api.nvim_create_augroup('gonvim__codelenses', {}),
    pattern = '*.go',
    callback = function()
      require('go.codelens').refresh()
    end,
  })
end

function M.run_action()
  local guihua = utils.load_plugin('guihua.lua', 'guihua.gui')
  local original_select = vim.ui.select

  if guihua then
    vim.ui.select = require('guihua.gui').select
  end

  codelens.run()
  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

function M.refresh()
  if _GO_NVIM_CFG.lsp_codelens ~= false then
    vim.lsp.codelens.refresh()
  end
end

return M
