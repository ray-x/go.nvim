local utils = require('go.utils')
local codelens = require('vim.lsp.codelens')

local M = {}

function M.setup()
  utils.log('enable codelens')
  vim.api.nvim_set_hl(0, 'LspCodeLens', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensText', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSign', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSeparator', { link = 'Boolean', default = true })
  vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI', 'InsertLeave' }, {
    group = vim.api.nvim_create_augroup('gonvim__codelenses', {}),
    pattern = { '*.go', '*.mod' },
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
  local found = false
  if _GO_NVIM_CFG.lsp_codelens ~= false then
    if not found then
      for _, lsp in pairs(vim.lsp.buf_get_clients()) do
        if lsp.name == 'gopls' then
          found = true
          break
        end
      end
    end
    if not found then
      return
    end
    vim.lsp.codelens.refresh()
  end
end

return M
